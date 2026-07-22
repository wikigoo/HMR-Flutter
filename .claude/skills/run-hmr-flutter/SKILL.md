---
name: run-hmr-flutter
description: Build, run, and drive the HMR Flutter app. Use when asked to start HMR, launch the web app, take a screenshot of its UI, click through the chat flow, reproduce a UI bug, or run its analyze/test gate.
---

HMR is a Persian (RTL) Flutter chat app targeting Android + Web. No Android
emulator is attachable on this machine, so the agent path is **web**: build a
release bundle, serve it with `serve.mjs`, and drive it with `driver.mjs` — a
zero-dependency Chrome DevTools Protocol driver that switches on Flutter's
accessibility tree and clicks/types by Persian label.

All paths are relative to the repo root (`D:\.HMR\HMR-Flutter`).

Verified on Windows 11 (PowerShell + Git Bash), Flutter 3.44.x, Node v24,
Chrome 150. Not verified on Linux.

## Prerequisites

- Flutter 3.44.x stable, Dart ≥3.2
- Node ≥ 20 — the driver needs the global `WebSocket` (verified on v24)
- Google Chrome. Auto-detected at the standard Windows path; override with
  `CHROME_PATH`.

No `apt-get` or npm install — both scripts have zero dependencies.

## Setup

```bash
flutter pub get
```

## Run (agent path)

**Use the release build + static server.** It is the only setup that survives
more than one driver run (see the DWDS gotcha below).

```bash
flutter build web --release                                   # ~35s
node .claude/skills/run-hmr-flutter/serve.mjs --root build/web --port 5600 &
```

Then drive it — this is the committed guest-path flow, end to end:

```bash
node .claude/skills/run-hmr-flutter/driver.mjs \
  --url http://127.0.0.1:5600 --fresh \
  --script .claude/skills/run-hmr-flutter/smoke.txt
```

Expected tail: `expect یک گوشی خوب -> ok`, exit `0`. Exit `1` = an assertion
failed, `2` = driver error. Screenshots land in
`.claude/skills/run-hmr-flutter/shots/` (gitignored).

Rebuild (`flutter build web --release`) after changing anything in `lib/`;
the server just serves files and needs no restart.

One-off command:

```bash
node .claude/skills/run-hmr-flutter/driver.mjs --url http://127.0.0.1:5600 -- tree
```

### Driver flags

| flag | meaning |
|---|---|
| `--url <u>` | app URL (default `http://127.0.0.1:5599`) |
| `--script <f>` | UTF-8 file, one command per line, `#` comments |
| `--fresh` | clear `localStorage` first → lands on the welcome screen |
| `--headed` | show the browser (default headless) |
| `--width/--height` | viewport (default `1280x860`) |
| `--port <n>` | CDP port (default 9333) |

### Script grammar

| command | what it does |
|---|---|
| `tree` | dump actionable nodes (buttons, fields, labels, text) |
| `click <substring>` | click the button whose label contains it; polls up to 12s |
| `click_until <substring> :: <expected>` | re-click until `<expected>` appears (30s). Use for any screen transition — see the swallowed-click gotcha |
| `type <field-label> :: <text>` | focus the field, insert text via CDP |
| `expect <substring>` | assert text is on screen; polls, fails the run if absent |
| `shot <path>` | PNG screenshot |
| `wait <ms>` | sleep |
| `console` / `net` | dump console messages / failed requests |
| `reset` | clear localStorage and reload |
| `eval <arrow-fn>` | run a function in the page, print its JSON result |

Prefer `--script` over `--` for anything containing Persian — it sidesteps
shell quoting, and the `::` separator disambiguates `type`'s two arguments.

## Run (human path)

```bash
flutter run -d chrome    # real browser window; 'q' in the console quits
```

For iterating on `lib/` with hot reload, `flutter run -d web-server
--web-port=5599 --web-hostname=127.0.0.1` also works — but see the DWDS
gotcha: it tolerates exactly one driver run per server start.

## Test

```bash
flutter analyze   # verified: "No issues found!"
flutter test      # verified: 7 tests, all passing
```

Per CLAUDE.md, changes under `android/` or to `pubspec.yaml` also need a real
`flutter build apk --release`. Not covered here — no Android device was
attached, so that path is unverified by this skill.

## Gotchas

- **`flutter run -d web-server` serves exactly ONE app connection.** In debug
  mode it binds a DWDS debug service to the first browser that connects. When
  the driver's Chrome exits, every later page load stalls forever on the splash
  screen — DDC reports `830/830 scripts` loaded, the DOM still holds only
  `<picture id="splash">`, and no error is printed anywhere. It looks exactly
  like a broken app or a hung driver. This is why the agent path uses a release
  build behind `serve.mjs`, which is reconnectable indefinitely (verified: two
  consecutive runs, same server, both exit 0).
- **Flutter web paints to `<canvas>` — there is no DOM to query.** Nothing is
  findable until you click the hidden `<flt-semantics-placeholder>` to switch
  on the accessibility tree. The driver does this and prints
  `semantics: enabled`. Any tool that waits on page text without this (a plain
  "wait for selector") times out against a perfectly healthy app.
- **Buttons and fields expose labels differently.** `flt-semantics[role=button]`
  carries its label as **textContent** with a *null* `aria-label`;
  `<input>`/`<textarea>` carry **aria-label**. A single aria-label query finds
  no buttons at all. The driver looks up each separately.
- **The semantics tree rebuilds asynchronously after every screen change**, so a
  one-shot lookup fires before the nodes exist and reports an empty screen.
  Every driver lookup polls (`until()`, 12s).
- **Setting `.value` + dispatching an `input` event does NOT reach Flutter's
  text model.** The DOM value updates and it looks like it worked, but the send
  button submits nothing. Text must go through CDP `Input.insertText` on the
  focused field.
- **Flutter does not mirror typed text back onto the DOM node**, so reading
  `input.value` after typing returns `''` even on success. Never assert typing
  that way — assert the resulting bubble with `expect` after sending.
- **A click can be silently swallowed.** The welcome screen's buttons are inert
  until `AuthProvider.init()` settles (slower now that the GIS iframe 403s).
  A click landing in that window reports `ok` and does nothing — the run then
  fails several steps later at an unrelated-looking `expect`. This is
  intermittent: the same command passes three times and fails the fourth. Use
  `click_until` for every screen transition; plain `click` is only safe for
  actions that don't navigate.
- **Viewport width changes both the layout and the Persian strings.**
  `home_shell.dart` branches on width. Verified: **1280** → desktop two-pane
  sidebar saying `گفتگوی جدید`; **420 and 800** → mobile conversations list
  saying `گفت‌وگوی جدید` — note the ZWNJ (U+200C). A selector tuned on one
  layout silently misses the other; match on a short distinctive substring.
- **`Input.dispatchMouseEvent` (trusted coordinate clicking) does not drive this
  app** at any width tried — the semantics-node `.click()` is what works. Don't
  reach for coordinate clicking as a fallback; it was tried and removed.
- **SharedPreferences is `localStorage` with a `flutter.` prefix** —
  `flutter.seen_welcome`, `flutter.conversations_index`. The welcome screen
  shows once, so use `--fresh` to get it back.
- **Screenshot immediately after boot can miss image assets** (the welcome orb
  renders as an empty disc). Add `wait 1000` before `shot`.
- **Headless CanvasKit needs SwiftShader** — the driver passes
  `--use-gl=swiftshader --enable-unsafe-swiftshader`.

### Two failures that are environmental, not bugs

- **Every chat message fails locally** with `net::ERR_FAILED` and the Persian
  error bubble `خطای غیرمنتظره‌ای رخ داد`. The server is fine —
  `curl https://srv.hmrbot.com/api/v1/version` returns `200` — but an `OPTIONS`
  preflight carrying a localhost `Origin` comes back with **no
  `Access-Control-Allow-Origin`**, so Chrome blocks it. The nginx reverse proxy
  allows production origins only. Expect the error bubble on any local run; it
  exercises the retry path rather than a real answer.
- **Google sign-in cannot be tested locally.** `accounts.google.com/gsi/button`
  returns **HTTP 403** with `The given origin is not allowed for the given
  client ID` — localhost is not a registered JS origin in the `hmrbot-app` GCP
  project. Only the guest path is drivable. Do not "fix" this in code.

## Troubleshooting

- **`DRIVER ERROR: Flutter never booted`, and the dumped DOM shows only
  `PICTURE,SOURCE,IMG,SCRIPT`** — you are on a `flutter run -d web-server`
  instance that has already served one client. Restart it, or switch to the
  release + `serve.mjs` path.
- **`Failed to bind web development server ... errno = 10048`** — port still
  held. Stopping the background task does not free it; the `dartvm` process
  survives. Kill it:
  `Get-NetTCPConnection -LocalPort 5599 -State Listen | %{ Stop-Process -Id $_.OwningProcess -Force }`
- **`CLICK FAIL "x" — buttons present: []`** — semantics never came on, or you
  are on an unexpected screen. Run `tree` to see what is actually there.
- **`CLICK FAIL` listing buttons that look correct** — ZWNJ mismatch
  (`گفت‌وگو` vs `گفتگو`). Match a shorter substring.
- **A run fails at an `expect` for a screen you thought you had navigated to,
  and the dumped labels are from the *previous* screen** — the preceding click
  was swallowed. Switch that step to `click_until`.
- **`net::ERR_ABORTED Document` in `net` output** — harmless; it is the reload
  `--fresh` performs after clearing storage.
- **`claude-in-chrome` MCP reports "not connected"** — irrelevant. This driver
  launches and owns its own Chrome.
