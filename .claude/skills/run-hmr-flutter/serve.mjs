#!/usr/bin/env node
// Minimal static file server for build/web — zero dependencies.
//
// Why not `flutter run -d web-server`? In debug mode that binds a DWDS debug
// service to the FIRST browser that connects. Once that browser exits, every
// later page load hangs on the splash screen forever. A driver you can only
// run once is useless, so automated runs serve a release build from here.
//
//   node .claude/skills/run-hmr-flutter/serve.mjs [--root build/web] [--port 5600]

import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { join, extname, normalize } from 'node:path';

const argv = process.argv.slice(2);
const opt = (n, d) => {
  const i = argv.indexOf(n);
  return i === -1 ? d : argv[i + 1];
};

const ROOT = opt('--root', 'build/web');
const PORT = Number(opt('--port', '5600'));

const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.bin': 'application/octet-stream',
  '.symbols': 'text/plain; charset=utf-8',
};

createServer(async (req, res) => {
  try {
    const url = decodeURIComponent(req.url.split('?')[0]);
    // Strip leading slashes so normalize() cannot escape ROOT via "..".
    let rel = normalize(url).replace(/^([/\\])+/, '');
    if (rel.startsWith('..')) rel = '';
    let file = join(ROOT, rel || 'index.html');

    let s = await stat(file).catch(() => null);
    if (s?.isDirectory()) {
      file = join(file, 'index.html');
      s = await stat(file).catch(() => null);
    }
    // Flutter web is a SPA — unknown paths fall back to index.html.
    if (!s) file = join(ROOT, 'index.html');

    const body = await readFile(file);
    res.writeHead(200, {
      'Content-Type': TYPES[extname(file).toLowerCase()] || 'application/octet-stream',
      'Cache-Control': 'no-store',
      // CanvasKit's multi-threaded paths want a cross-origin-isolated context.
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Cross-Origin-Embedder-Policy': 'credentialless',
    });
    res.end(body);
  } catch (e) {
    res.writeHead(500).end(String(e));
  }
}).listen(PORT, '127.0.0.1', () => {
  console.log(`serving ${ROOT} at http://127.0.0.1:${PORT}`);
});
