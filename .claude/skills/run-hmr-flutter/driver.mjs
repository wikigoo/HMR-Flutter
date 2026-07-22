#!/usr/bin/env node
// Zero-dependency Chrome DevTools Protocol driver for the HMR Flutter web app.
//
// Flutter web paints to a <canvas>; there is no DOM to query until the
// accessibility tree is switched on. This driver boots Chrome, turns on
// Flutter's semantics, and then exposes label-based click/type/assert
// against the resulting <flt-semantics> nodes.
//
// Usage:
//   node driver.mjs --url http://127.0.0.1:5599 --script flow.txt
//   node driver.mjs --url http://127.0.0.1:5599 -- tree
//
// See SKILL.md for the command grammar.

import { spawn } from 'node:child_process';
import { mkdtempSync, writeFileSync, readFileSync, mkdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname, resolve } from 'node:path';

// ---------------------------------------------------------------- args

const argv = process.argv.slice(2);
const opt = (name, dflt) => {
  const i = argv.indexOf(name);
  return i === -1 ? dflt : argv[i + 1];
};
const has = (name) => argv.includes(name);

const URL_ = opt('--url', 'http://127.0.0.1:5599');
const PORT = Number(opt('--port', '9333'));
const HEADED = has('--headed');
// home_shell.dart branches on width: wide -> two-pane desktop sidebar,
// narrow -> conversations list + drawer. Headless defaults to 800x600,
// which silently gives you the MOBILE layout (and different Persian labels).
const WIDTH = Number(opt('--width', '1280'));
const HEIGHT = Number(opt('--height', '860'));
const FRESH = has('--fresh'); // clear localStorage before running -> welcome screen
const SCRIPT = opt('--script', null);

let cmds = [];
if (SCRIPT) {
  cmds = readFileSync(SCRIPT, 'utf8').split(/\r?\n/);
} else {
  const i = argv.indexOf('--');
  if (i !== -1) cmds = [argv.slice(i + 1).join(' ')];
}
cmds = cmds.map((l) => l.trim()).filter((l) => l && !l.startsWith('#'));
if (!cmds.length) cmds = ['tree'];

// ---------------------------------------------------------------- chrome

function chromePath() {
  if (process.env.CHROME_PATH) return process.env.CHROME_PATH;
  const candidates =
    process.platform === 'win32'
      ? [
          'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
          'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
        ]
      : ['/usr/bin/google-chrome', '/usr/bin/chromium', '/usr/bin/chromium-browser'];
  for (const c of candidates) {
    try {
      readFileSync(c);
      return c;
    } catch {
      /* keep looking */
    }
  }
  return candidates[0];
}

const profile = mkdtempSync(join(tmpdir(), 'hmr-cdp-'));
const chromeArgs = [
  `--remote-debugging-port=${PORT}`,
  `--user-data-dir=${profile}`,
  '--no-first-run',
  '--no-default-browser-check',
  '--disable-features=Translate,MediaRouter',
  // CanvasKit needs WebGL; headless Chrome serves it through SwiftShader.
  '--use-gl=swiftshader',
  '--enable-unsafe-swiftshader',
  'about:blank',
];
if (!HEADED) chromeArgs.unshift('--headless=new');

const chrome = spawn(chromePath(), chromeArgs, { stdio: 'ignore' });
const cleanup = () => {
  try {
    chrome.kill();
  } catch {
    /* already gone */
  }
};
process.on('exit', cleanup);
process.on('SIGINT', () => {
  cleanup();
  process.exit(130);
});

// ---------------------------------------------------------------- cdp

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Flutter rebuilds its semantics tree asynchronously after every screen
// change, so a node you ask for often does not exist for a second or two.
// Every lookup polls instead of asserting once.
async function until(fn, ms = 12000, step = 250) {
  const t0 = Date.now();
  for (;;) {
    const r = await fn();
    if (r && r.ok) return r;
    if (Date.now() - t0 > ms) return r;
    await sleep(step);
  }
}

async function endpoint() {
  for (let i = 0; i < 100; i++) {
    try {
      const r = await fetch(`http://127.0.0.1:${PORT}/json/version`);
      return (await r.json()).webSocketDebuggerUrl;
    } catch {
      await sleep(200);
    }
  }
  throw new Error(`Chrome never opened a debugging port on ${PORT}`);
}

class Session {
  constructor(ws) {
    this.ws = ws;
    this.id = 0;
    this.pending = new Map();
    this.console = [];
    this.failed = [];
    ws.addEventListener('message', (e) => {
      const m = JSON.parse(e.data);
      if (m.id && this.pending.has(m.id)) {
        const { resolve: res, reject } = this.pending.get(m.id);
        this.pending.delete(m.id);
        m.error ? reject(new Error(JSON.stringify(m.error))) : res(m.result);
        return;
      }
      if (m.method === 'Runtime.consoleAPICalled') {
        const text = (m.params.args || [])
          .map((a) => a.value ?? a.description ?? a.type)
          .join(' ');
        this.console.push(`[${m.params.type}] ${text}`);
      }
      if (m.method === 'Runtime.exceptionThrown') {
        this.console.push(`[exception] ${m.params.exceptionDetails.text}`);
      }
      if (m.method === 'Network.loadingFailed') {
        this.failed.push(`${m.params.errorText} ${m.params.type}`);
      }
      if (m.method === 'Network.requestWillBeSent') {
        this.urls ??= new Map();
        this.urls.set(m.params.requestId, m.params.request.url);
      }
      if (m.method === 'Network.responseReceived') {
        const s = m.params.response.status;
        if (s >= 400) this.failed.push(`HTTP ${s} ${m.params.response.url}`);
      }
    });
  }

  send(method, params = {}) {
    const id = ++this.id;
    this.ws.send(JSON.stringify({ id, method, params }));
    return new Promise((res, rej) => this.pending.set(id, { resolve: res, reject: rej }));
  }

  async eval(fn, ...args) {
    const expr = `(${fn})(${args.map((a) => JSON.stringify(a)).join(',')})`;
    const r = await this.send('Runtime.evaluate', {
      expression: expr,
      returnByValue: true,
      awaitPromise: true,
    });
    if (r.exceptionDetails) throw new Error(r.exceptionDetails.text + ' :: ' + expr.slice(0, 120));
    return r.result.value;
  }
}

async function connect(url) {
  const ws = new WebSocket(url);
  await new Promise((res, rej) => {
    ws.addEventListener('open', res, { once: true });
    ws.addEventListener('error', () => rej(new Error(`cannot connect: ${url}`)), { once: true });
  });
  return new Session(ws);
}

// ------------------------------------------------- in-page helpers

// Flutter renders buttons as <flt-semantics role=button> whose LABEL IS
// textContent (aria-label is null on buttons). Text fields are real
// <input>/<textarea> and DO carry aria-label. Hence two lookup paths.
const PAGE = {
  ready: () =>
    !!document.querySelector('flt-semantics-placeholder') ||
    document.querySelectorAll('flt-semantics').length > 0,

  enableSemantics: () => {
    const p = document.querySelector('flt-semantics-placeholder');
    if (p) {
      p.click();
      return 'enabled';
    }
    return document.querySelectorAll('flt-semantics').length ? 'already-on' : 'no-placeholder';
  },

  tree: () => {
    const out = [];
    for (const b of document.querySelectorAll('flt-semantics[role="button"]')) {
      const t = (b.textContent || '').trim().replace(/\s+/g, ' ');
      if (t) out.push({ kind: 'button', label: t });
    }
    for (const i of document.querySelectorAll('input,textarea')) {
      out.push({ kind: 'field', label: i.getAttribute('aria-label') || '', value: i.value });
    }
    for (const g of document.querySelectorAll('flt-semantics[aria-label]')) {
      const al = g.getAttribute('aria-label');
      if (al) out.push({ kind: 'label', label: al.trim().replace(/\s+/g, ' ') });
    }
    // Plain text nodes carry the chat bubbles / headings.
    for (const s of document.querySelectorAll('flt-semantics > span')) {
      const t = (s.textContent || '').trim();
      if (t) out.push({ kind: 'text', label: t });
    }
    const seen = new Set();
    return out.filter((o) => {
      const k = o.kind + '|' + o.label;
      if (seen.has(k)) return false;
      seen.add(k);
      return true;
    });
  },

  click: (needle) => {
    const norm = (s) => (s || '').trim().replace(/\s+/g, ' ');
    const btns = [...document.querySelectorAll('flt-semantics[role="button"]')];
    let t = btns.find((b) => norm(b.textContent).includes(needle));
    if (!t) {
      t = [...document.querySelectorAll('flt-semantics[aria-label]')].find((e) =>
        norm(e.getAttribute('aria-label')).includes(needle)
      );
    }
    if (!t) return { ok: false, saw: btns.map((b) => norm(b.textContent)) };
    t.click();
    return { ok: true, hit: norm(t.textContent) || t.getAttribute('aria-label') };
  },

  // Assigning .value and dispatching an 'input' event does NOT reach Flutter's
  // text model — the send button stays empty-handed. Focus here, then push the
  // characters through CDP Input.insertText so they go down the real pipeline.
  focusField: (label) => {
    const all = [...document.querySelectorAll('input,textarea')];
    const f = all.find((i) => (i.getAttribute('aria-label') || '').includes(label));
    if (!f) return { ok: false, saw: all.map((i) => i.getAttribute('aria-label')) };
    f.focus();
    return { ok: true };
  },

  fieldValue: (label) => {
    const f = [...document.querySelectorAll('input,textarea')].find((i) =>
      (i.getAttribute('aria-label') || '').includes(label)
    );
    return f ? f.value : '';
  },

  reset: () => {
    localStorage.clear();
    return 'cleared';
  },
};

// ---------------------------------------------------------------- main

let failures = 0;

const main = async () => {
  const browserWs = await endpoint();
  const browser = await connect(browserWs);
  const { targetId } = await browser.send('Target.createTarget', { url: 'about:blank' });

  const list = await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json();
  const page = list.find((t) => t.id === targetId);
  const s = await connect(page.webSocketDebuggerUrl);

  await s.send('Page.enable');
  await s.send('Runtime.enable');
  await s.send('Network.enable');
  await s.send('Emulation.setDeviceMetricsOverride', {
    width: WIDTH,
    height: HEIGHT,
    deviceScaleFactor: 1,
    mobile: false,
  });

  await s.send('Page.navigate', { url: URL_ });

  if (FRESH) {
    // localStorage is per-origin, so it only exists after the first load.
    for (let i = 0; i < 60; i++) {
      try {
        await s.eval(PAGE.reset);
        break;
      } catch {
        await sleep(250);
      }
    }
    await s.send('Page.navigate', { url: URL_ });
  }

  // Flutter's debug bundle takes a while (dart2js/DDC + CanvasKit wasm).
  let booted = false;
  for (let i = 0; i < 400; i++) {
    try {
      if (await s.eval(PAGE.ready)) {
        booted = true;
        break;
      }
    } catch {
      /* page still swapping documents */
    }
    await sleep(500);
  }
  if (!booted) {
    let dom = '(unreadable)';
    try {
      dom = await s.eval(() => ({
        len: document.body.innerHTML.length,
        head: document.body.innerHTML.slice(0, 300),
        tags: [...new Set([...document.body.querySelectorAll('*')].map((e) => e.tagName))].join(','),
      }));
    } catch {
      /* context gone */
    }
    console.error('console:\n' + (s.console.slice(-20).map((l) => '  ' + l).join('\n') || '  (none)'));
    console.error('dom: ' + JSON.stringify(dom));
    throw new Error('Flutter never booted — is the dev server up at ' + URL_ + '?');
  }

  console.log('semantics: ' + (await s.eval(PAGE.enableSemantics)));
  // Node count is a bad gate — the tree exists long before it has any
  // actionable nodes. Wait for a real button or field to show up.
  await until(async () => {
    const t = await s.eval(PAGE.tree);
    return { ok: t.some((n) => n.kind === 'button' || n.kind === 'field') };
  }, 20000);

  for (const line of cmds) {
    const sp = line.indexOf(' ');
    const cmd = sp === -1 ? line : line.slice(0, sp);
    const rest = sp === -1 ? '' : line.slice(sp + 1).trim();

    if (cmd === 'tree') {
      const t = await s.eval(PAGE.tree);
      console.log(t.map((n) => `  ${n.kind.padEnd(6)} ${n.label}`).join('\n'));
    } else if (cmd === 'click') {
      const r = await until(() => s.eval(PAGE.click, rest));
      if (!r.ok) {
        failures++;
        console.log(`CLICK FAIL "${rest}" — buttons present: ${JSON.stringify(r.saw)}`);
      } else console.log(`click ${rest} -> ok`);
      await sleep(500);
    } else if (cmd === 'type') {
      const [label, text] = rest.split('::').map((x) => x.trim());
      const r = await until(() => s.eval(PAGE.focusField, label));
      if (!r.ok) {
        failures++;
        console.log(`TYPE FAIL "${label}" — fields present: ${JSON.stringify(r.saw)}`);
      } else {
        await s.send('Input.insertText', { text: text ?? '' });
        await sleep(400);
        // Flutter pulls the text into its own editing model and does not
        // reliably mirror it back onto the DOM node, so an empty value here
        // is NOT a failure. Assert with `expect` after sending instead.
        const got = await s.eval(PAGE.fieldValue, label);
        console.log(`type ${label} -> ${got || '(accepted; Flutter does not mirror it to the DOM)'}`);
      }
      await sleep(300);
    } else if (cmd === 'click_until') {
      // The welcome screen's buttons are inert until AuthProvider.init()
      // settles, and a click landing in that window is silently swallowed —
      // it reports success and nothing happens. Re-click until the target
      // screen actually appears.
      const [target, expected] = rest.split('::').map((x) => x.trim());
      const r = await until(
        async () => {
          const t = await s.eval(PAGE.tree);
          if (t.some((n) => n.label.includes(expected))) return { ok: true };
          await s.eval(PAGE.click, target);
          return { ok: false, saw: t.map((n) => n.label) };
        },
        30000,
        1200
      );
      if (!r.ok) {
        failures++;
        console.log(`CLICK_UNTIL FAIL "${target}" never reached "${expected}"`);
      } else console.log(`click_until ${target} -> ${expected}`);
    } else if (cmd === 'expect') {
      const r = await until(async () => {
        const t = await s.eval(PAGE.tree);
        return { ok: t.some((n) => n.label.includes(rest)), saw: t.map((n) => n.label) };
      });
      if (!r.ok) {
        failures++;
        console.log(`EXPECT FAIL: "${rest}" not on screen — saw ${JSON.stringify(r.saw)}`);
      } else console.log(`expect ${rest} -> ok`);
    } else if (cmd === 'shot') {
      const out = resolve(rest || 'shot.png');
      mkdirSync(dirname(out), { recursive: true });
      const { data } = await s.send('Page.captureScreenshot', { format: 'png' });
      writeFileSync(out, Buffer.from(data, 'base64'));
      console.log(`shot -> ${out}`);
    } else if (cmd === 'wait') {
      await sleep(Number(rest) || 1000);
    } else if (cmd === 'console') {
      console.log(s.console.slice(-40).map((l) => '  ' + l).join('\n') || '  (none)');
    } else if (cmd === 'net') {
      console.log(s.failed.slice(-30).map((l) => '  ' + l).join('\n') || '  (no failures)');
    } else if (cmd === 'reset') {
      console.log(await s.eval(PAGE.reset));
      await s.send('Page.navigate', { url: URL_ });
      await sleep(4000);
    } else if (cmd === 'eval') {
      console.log(JSON.stringify(await s.eval(new Function(`return (${rest})`)()), null, 2));
    } else {
      failures++;
      console.log(`unknown command: ${cmd}`);
    }
  }
};

main()
  .then(() => {
    cleanup();
    process.exit(failures ? 1 : 0);
  })
  .catch((e) => {
    console.error('DRIVER ERROR: ' + e.message);
    cleanup();
    process.exit(2);
  });
