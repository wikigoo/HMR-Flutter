# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Project Overview

**HMR (همر)** is a Persian-language AI chatbot for the Iranian mobile market. It delivers smart hardware recommendations across five product pillars: **Phone · Laptop · Tablet · Earphones · Accessories**.

| Concern | Detail |
|---|---|
| Frontend | Flutter (Android + Web), Android-first |
| AI backend | Flowise on a self-hosted VPS (`https://srv.hmrbot.com`) |
| Auth | Google Sign-In via **Google Identity Services** (`google_sign_in ^7.2.0`, singleton API — see Auth notes below) — Google Cloud project **`hmrbot-app` (`326113602877`)**. **No Firebase Auth** — no `firebase_auth`/`firebase_core` dependency (a `google-services.json` being present does not imply otherwise). |
| Package id | `com.hmrbot` |
| Storage | SQLite (messages) + SharedPreferences (conversation index) — the conversation **list** is 100% on-device with no sync backend. Signed-in users do get server-side Flowise **memory** continuity (invariant 5) — that is not list sync. |
| Locale | Persian (Farsi), RTL, Jalali (Shamsi) calendar |

---

## Non-Negotiable Product Invariants

These rules must **never** be broken regardless of the task at hand.

1. **Language and direction:** The UI is Persian (Farsi), RTL. Persian text renders in **Vazirmatn**; Latin text and the "HMR" wordmark render in **Rubik** — both bundled locally with per-glyph `fontFamilyFallback` (Vazirmatn ⇄ Rubik), never fetched at runtime. Never change the language or text direction, and never render Persian in anything but Vazirmatn.
2. **Branding:** Dark navy/cyan color palette. Base hue tokens are generated (see `app_colors.g.dart` below); app-specific composites (glass fills, bubble gradients) live hand-authored in `AppTheme`. Do not alter brand colors or the HMR orb widget.
3. **Five pillars:** Phone · Laptop · Tablet · Earphones · Accessories — do not remove, rename, or reorder them.
4. **Price disclaimer:** The app must never present a specific price as definitive. Users must always be prompted to verify prices at the point of sale. The `PriceDisclaimer` widget implements this contract.
5. **Honesty boundary:** The AI assistant must never claim capabilities that do not exist. **Partial sync only:** a *signed-in* user's Flowise conversation **memory** follows them across web and mobile (the Flowise `sessionId` is the Google `sub`). But the **conversation list is still 100% on-device** — there is **no list/history sync backend**. Do not claim full "cross-device sync" in UI copy; at most, "your signed-in chat continues across your devices."
6. **Flowise endpoints:** Never change `_chatflowId`, `_baseUrl`, or the `sessionId` **field/signature** in `api_service.dart`. `ChatProvider` sends `userId ?? conversationId` as `sessionId` — `api_service.dart` itself just forwards whatever it's given. Any modification to the API layer requires the live VPS reverse proxy to keep working (see Security section).

---

## Architecture

```
lib/
├── main.dart                        Entry point: SentryFlutter.init, error boundary,
│                                    MultiProvider, locale (fa-IR), RTL Directionality
├── theme/
│   ├── app_theme.dart                Design tokens consumed by widgets: text styles,
│   │                                gradients, Markdown stylesheet, glass composites
│   │                                (all Color(0xAARRGGBB) literals — no withOpacity)
│   └── app_colors.g.dart             GENERATED — base brand hues pulled from
│                                    wikigoo/HMR-Design (tokens/colors.css) via
│                                    `tool/gen_tokens.sh`; shared with the HMR-Astro
│                                    website. CI (design-tokens-drift.yml) fails if
│                                    this file drifts from the source. Never hand-edit.
├── l10n/
│   └── app_strings.dart             Single source of truth for all Persian UI copy
│                                    (const strings + parameterized functions). The
│                                    app is Persian-only; this is a copy deck, not i18n.
├── providers/                       ChangeNotifier state — Provider package
│   ├── auth_provider.dart           Google Sign-In state machine (see Auth notes)
│   ├── chat_provider.dart           Per-session messages, API dispatch, retry logic;
│                                    takes a ChatRepository (constructor injection)
│   └── conversations_provider.dart  Conversation index — SharedPreferences JSON array;
│                                    message CRUD delegated to ChatRepository
├── repositories/
│   └── chat_repository.dart         App-scoped data-access seam over ApiService +
│                                    ChatDatabase; the only file importing chat_database
├── screens/
│   ├── welcome_screen.dart          First-launch panel (design system's "Login"):
│                                    HMR orb, Google button, guest pill. NOT an auth
│                                    gate — both paths enter, failed sign-in falls
│                                    through to guest. Shown once, gated on the
│                                    `seen_welcome` SharedPreferences flag set by
│                                    `_FirstRun` in main.dart
│   ├── home_shell.dart              Responsive entry: narrow → conversations list
│                                    + drawer (delegates to conversations_screen.dart);
│                                    wide (web/desktop) → persistent two-pane sidebar
│                                    with its own account block (_SidebarAccount)
│   ├── conversations_screen.dart    Mobile history list + slide-in sidebar drawer
│                                    (new-chat row, search, links, in-drawer chat
│                                    history, one account button —
│                                    _SidebarAccountButton: guest CTA / signed-in
│                                    sheet with sign-out + delete-account), new-chat
│                                    FAB, ghost-conversation cleanup on back-nav
│   └── chat_screen.dart             Chat surface, composer, clear-history confirm,
│                                    five-pillar empty state + PriceDisclaimer
├── services/
│   └── api_service.dart             Flowise REST client — offline guard, retry loop,
│                                    _TransientError / ApiException separation
├── database/
│   ├── chat_database.dart           SQLite singleton via sqflite; messages table
│   ├── db_factory_stub.dart         No-op on native (sqflite ships a working factory)
│   └── db_factory_web.dart          Web: routes sqflite through sqflite_common_ffi_web
│                                    (IndexedDB + sqlite3.wasm). Swapped in via a
│                                    conditional import in chat_database.dart.
├── models/
│   ├── conversation_model.dart      JSON-serialisable conversation record
│   └── message_model.dart           Message: uuid id, role, text, timestamp, isError flag
├── widgets/
│   ├── chat_bubble.dart             AI bubble (Markdown + error state) + user bubble
│   ├── confirm_dialog.dart          Reusable dark-glass confirmation dialog (title/body/label)
│   ├── price_disclaimer.dart        Amber glassmorphism disclaimer strip
│   ├── google_mark.dart             Shared 4-colour Google "G" (welcome + sidebar sign-in)
│   ├── google_signin_web_button.dart      Conditional export switching on dart.library.js_interop
│   ├── google_signin_web_button_stub.dart  — native builds link this no-op stub
│   ├── google_signin_web_button_web.dart   — web builds link this; renders the real
│   │                                GIS button via package:google_sign_in_web (see
│   │                                Auth notes — google_sign_in v7 requires it)
│   ├── hmr_avatar.dart              HMR orb — flat disc + cyan hairline (no gradient ring)
│   └── hmr_background.dart          Glassmorphism radial-gradient background
└── utils/
    └── jalali.dart                  Gregorian → Shamsi date formatting

android/
├── app/
│   ├── build.gradle.kts             compileSdk=targetSdk=36, minSdk=flutter.minSdkVersion;
│   │                                resolves release signing from CI env vars
│   │                                (HMR_KEY_ALIAS/HMR_KEY_PASSWORD/HMR_STORE_PASSWORD/
│   │                                HMR_KEYSTORE_PATH) or android/key.properties
│   │                                (gitignored, local-only) — falls back to an
│   │                                unsigned/debug-signed release build if neither exists
│   ├── proguard-rules.pro           Keep/dontwarn for GMS, sqflite, shared_preferences,
│   │                                lifecycle, custom-tabs, url_launcher
│   └── src/main/
│       └── AndroidManifest.xml      INTERNET permission, <queries> for https VIEW +
│                                    com.google.android.gms, allowBackup=false
└── settings.gradle.kts              AGP 9.0.1, Kotlin 2.3.20; Aliyun Maven mirrors
```

---

## Key Patterns and Contracts

### API layer (`api_service.dart`)

- `sendMessage()` checks connectivity **before** making any HTTP call, then does a light pre-flight probe to `/api/v1/version` to catch captive portals / DNS failures / server-down before the real 30-second request.
- Retriable failures (`TimeoutException`, `ClientException`, HTTP 502/503/504) are wrapped in the private `_TransientError` class and retried up to **2 times** with **1 s / 2 s** backoffs.
- Terminal failures (HTTP 401/403/500, `FormatException`, empty body) are thrown as `ApiException` immediately — no retry.
- All error messages in `ApiException.message` are in Persian and are safe to display directly in the chat UI.
- **No `Authorization` header is sent by the client.** The Flowise Bearer token is injected server-side by the nginx reverse proxy (`hmr-auth.conf`) — the client binary carries no secrets. (`.github/workflows/build-release.yml` still passes a leftover `--dart-define=HMR_API_TOKEN=...` to the build; nothing in `lib/` reads it — harmless but stale, safe to remove if touching that workflow.)

### Chat error state (`chat_provider.dart` + `message_model.dart`)

- `MessageModel` carries an `isError` flag. Error messages are **not persisted** to SQLite — they are ephemeral display-only objects.
- `ChatProvider._lastFailedText` stores the last failed user input so `retryLastMessage()` can replay the API call without re-adding a user bubble.
- `retryLastMessage()` removes the last error bubble before re-attempting.

### Confirmation dialogs (`confirm_dialog.dart`)

- All destructive actions (delete conversation, clear history) use `ConfirmDialog` — a parameterised dark-glass dialog returning `bool?` via `showDialog<bool>`.
- The confirm button always uses the red fill `Color(0x33FF5470)` / border `Color(0x66FF5470)` to signal danger. Do not soften these colors.

### Ghost-conversation cleanup (`conversations_screen.dart`)

- After returning from `ChatScreen`, `_openConversation()` calls `ChatRepository.hasMessages(conv.id)` (the UI no longer touches `ChatDatabase` directly).
- If there are no messages, `deleteConversation()` is called silently. This handles both new conversations the user immediately backed out of and any legacy empty records.

### Storage split

| Data | Backend | Notes |
|---|---|---|
| Conversation index | `SharedPreferences` → key `conversations_index` | JSON array of `ConversationModel`; sorted by `updatedAt` descending |
| Messages | SQLite `messages` table | `conv_id` + `ts` composite index; error messages excluded |

### Design tokens

Base hue tokens (`HmrTokens` in `app_colors.g.dart`) are **generated** from `wikigoo/HMR-Design` (`tokens/colors.css`) via `bash tool/gen_tokens.sh` — the same source the HMR-Astro website uses, so brand colors stay in sync across properties. CI fails if the committed file drifts from source; never hand-edit it. App-specific composites (glass fills, bubble gradients) are hand-authored in `AppTheme`. **Never** use `.withOpacity()` anywhere — Dart 3.x lint flags it; use `Color(0xAARRGGBB)` literals instead. The Markdown stylesheet for AI bubbles is `AppTheme.markdown(context)`.

### Fonts

- `Vazirmatn` — all Persian UI text (`AppTheme.fontFa`); leads Persian styles, with `Rubik` as `fontFamilyFallback` so embedded Latin (device names, numerals) still renders in Rubik.
- `Rubik` — Latin brand text / the "HMR" wordmark (`AppTheme.fontLatin`); bundled static weights 400/500/600/700/800, with `Vazirmatn` as fallback. **Bundled locally, never fetched at runtime** — `google_fonts` was rejected because the Google CDN is unreliable in Iran.

### Performance note on bubbles

`_GlassBubble` (inside `chat_bubble.dart`) intentionally uses **no** `BackdropFilter`. A real blur per bubble destroys frame rate on mid-range Android while the list scrolls. The heavy blur is reserved for static elements (composer bar, confirm dialog backdrop).

---

## Build Setup

### Toolchain

Flutter 3.44.x (stable channel) · Dart ≥3.2.0 · AGP 9.0.1 · Kotlin 2.3.20 · compileSdk/targetSdk 36.

### Aliyun mirror (required for development in Iran)

Create `~/.gradle/init.d/aliyun-mirror.gradle`:

```groovy
allprojects {
    buildscript {
        repositories {
            maven { url 'https://maven.aliyun.com/repository/google' }
            maven { url 'https://maven.aliyun.com/repository/central' }
            maven { url 'https://maven.aliyun.com/repository/public' }
        }
    }
}
```

Required because `sqflite_android` hardcodes `google()` in its buildscript classpath, which resolves to `dl.google.com` — inaccessible from Iran without this redirect.

### Build-time variables (`--dart-define`)

| Variable | Required | Purpose |
|---|---|---|
| `SENTRY_DSN` | No | Sentry project DSN; empty string disables Sentry silently |

### Common commands

```bash
flutter pub get                     # install dependencies
flutter analyze                     # lint — must return zero issues before committing
flutter test                        # run the full test suite
flutter test test/chat_provider_test.dart          # run a single test file
flutter test --plain-name "guest button calls onDone"  # run a single test by name
flutter run                         # debug run (device/emulator)
flutter run -d chrome               # debug run in the browser
flutter build apk --release         # signed release APK (see signing below)
flutter build appbundle --release   # signed release AAB, for Google Play
flutter build web --release         # release web build
```

Signing is read from env vars in CI (`HMR_KEY_ALIAS`, `HMR_KEY_PASSWORD`, `HMR_STORE_PASSWORD`, `HMR_KEYSTORE_PATH`) or from `android/key.properties` (gitignored) locally; see `android/app/build.gradle.kts` for the exact resolution order. If neither is present, `hasSigningConfig` is false and the release build type is left unsigned rather than failing.

### Lint rules

`analysis_options.yaml` extends `flutter_lints` plus four project-specific rules: `prefer_const_constructors`, `prefer_const_declarations`, `avoid_print`, `prefer_single_quotes`.

### Test suite

`test/widget_test.dart` (smoke test), `test/chat_provider_test.dart` (repository-injected provider tests), `test/welcome_screen_test.dart` (layout + guest-path-never-a-dead-end), `test/chat_bubble_test.dart` (in-bubble controls keep a ≥44dp hit area).

---

## Deployment (web)

**`https://hmrbot.com/ai` is this Flutter web build**, served by the Cloudflare Worker **`hmr-flutter-bot`** — verified 2026-07-22 (the page returns `flutter_bootstrap` and the app's own `<title>`). It is an **assets-only** Worker: no script, just static file serving. The whole config is `wrangler.toml` at the repo root:

```toml
name = "hmr-flutter-bot"
compatibility_date = "2026-07-20"
[assets]
directory = "./build/web"
```

Things that are not obvious from the repo:

- **`build/` is gitignored — zero tracked files.** Cloudflare's checkout contains no `build/web`. The deploy therefore depends entirely on a **build command configured in the Cloudflare dashboard** (not in this repo) running `flutter build web --release`. If that command is ever cleared or fails, wrangler deploys an empty asset directory and blanks the live app. Nothing in the repo will warn you.
- **The build is triggered by the Cloudflare↔GitHub integration, configured in the Cloudflare dashboard — not by anything under `.github/`.** It watches the whole repo with no path filter, so **every** commit to `main` ships a production deploy of the public app, including docs- or tooling-only commits (e.g. `.claude/**`). Contrast the GitHub Actions workflows, which are correctly scoped: `design-tokens-drift.yml` uses `paths:` and skips unrelated changes.
- Narrowing this is a dashboard change (Worker → Settings → Builds → build watch paths) and **requires user action** — do not attempt it autonomously. Sensible watch paths: `lib/**`, `web/**`, `assets/**`, `pubspec.yaml`, `wrangler.toml`.
- The `hmr-flutter-bot.workers.dev` hostname does not resolve; the Worker is reached through the `hmrbot.com` route.

Treat any merge to `main` as a live production deploy of `hmrbot.com/ai` unless and until path filtering is configured.

---

## Auth notes

`google_sign_in ^7.2.0` is a **major, API-incompatible** rewrite from the `^6.x` line this app previously used:

- `GoogleSignIn(...)` constructor → singleton `GoogleSignIn.instance`; `initialize({clientId, serverClientId, ...})` **must be awaited exactly once** before any other member is touched. `AuthProvider.init()` guards this with `_initialized`/`_initializing`, which only works because `AuthProvider` itself is a singleton (the single `ChangeNotifierProvider<AuthProvider>` in `main.dart`) — do not construct a second `AuthProvider`.
- `signInSilently()` → `attemptLightweightAuthentication()`; `signIn()` → `authenticate()`, which throws `GoogleSignInException` (check `.code == GoogleSignInExceptionCode.canceled`) instead of returning null on cancel.
- The `scopes` constructor argument is gone — `email`/`profile` identity comes free with authentication; separate `authorizationClient.authorizeScopes(...)` calls are only for extra Google API access this app doesn't need.
- **`authenticate()` is unsupported on web** — `google_sign_in_web`'s `supportsAuthenticate()` is hard-coded `false`, and calling it throws `UnimplementedError`. Web sign-in is only possible by rendering the real GIS button, which is why `widgets/google_signin_web_button*.dart` exists (restored 2026-07-21 — it had briefly been deleted, see below). `home_shell.dart`, `welcome_screen.dart`, and `conversations_screen.dart` all branch on `kIsWeb` to show `renderGoogleSignInButton()` instead of their normal custom button.
- Because the web button is a real DOM element the GIS SDK controls (not a Flutter `GestureDetector`), a click there never returns through a Future. `AuthProvider.init()` subscribes to `GoogleSignIn.instance.authenticationEvents` as the single source of truth for `_user` on **every** platform — on web these events come from the platform's own stream; on native they're synthesized by the package from `authenticate()`/`attemptLightweightAuthentication()` return values. The subscription is cancelled in `AuthProvider.dispose()`.
- Client id selection is unchanged in spirit: **web** gets `clientId = _webClientId` explicitly; **Android** gets `serverClientId = _webClientId` and no `clientId` at all — passing an Android clientId there fails sign-in with `ApiException 10` (`DEVELOPER_ERROR`), because the plugin resolves the Android OAuth client from the package name (`com.hmrbot`) + the release keystore's SHA-1 registered in Google Cloud, not from a supplied id.

**Web build status:** it was deleted as "dead" on 2026-07-18 (`hmrbot.com/ai` was believed to be served entirely by a native Astro+React UI), then needed restoring on 2026-07-21 once the `google_sign_in` v7 bump broke `flutter analyze` and it became clear `authenticate()` doesn't work on web at all without the GIS button widget. **Verified 2026-07-22: `web/` is a live production target** — `hmrbot.com/ai` serves this Flutter build via the `hmr-flutter-bot` Cloudflare Worker, not the Astro UI (see Deployment above). The earlier "believed to be Astro" assumption is wrong; do not act on it.

**Release SHA-1 registration:** verified current as of 2026-07-21 — `android/app/google-services.json`'s `oauth_client` array contains an Android client (`326113602877-1t3ade...`) bound to `com.hmrbot` with `certificate_hash` `b0171f0b877321b973abe315ad5f08704fd0ca4b`, which matches the production keystore's (`hmr-production.jks`, alias `hmr-prod`) actual SHA-1. Android release sign-in is not blocked on OAuth registration. (`google-services.json` is gitignored — each machine needs its own copy from the Firebase/GCP console or a secrets store.)

**Play App Signing:** not yet confirmed either way — still worth checking, since without it a lost/compromised `hmr-production.jks` cannot be rotated without breaking every existing user's update path.

---

## Security Rules (Absolute)

- **Never** print, log, or commit any secret: tokens, keystore passwords, `key.properties`, `google-services.json`.
- **Never** commit the keystore file under any circumstances.
- The Flowise API token is injected **server-side** by the nginx reverse proxy (`hmr-auth.conf`). The app sends no `Authorization` header and the client binary carries no secrets.

---

## Workflow

### Branch strategy

- Feature work: `feat/<description>`
- Bug fixes and hardening: `fix/<description>`
- One logical change per commit; commit message explains *why*, not just *what*
- Never force-push to published branches; never amend published commits

> Observed in practice: this repo also accumulates commits titled just `commit` landing directly on `main` (e.g. the commit that bumped `google_sign_in` to `^7.2.0` without updating the calling code). These read like an external auto-commit tool rather than manual `git commit` calls. Don't assume `main`'s tip has been reviewed — check `flutter analyze` before trusting it compiles.

### Verification gate

After every code change, before committing:

1. `flutter analyze` — must return **zero issues**
2. `flutter test` — full suite must pass
3. For any change touching `android/` or `pubspec.yaml`: a real `flutter build apk --release` (or `appbundle`), not just `analyze` — dependency bumps can compile-break platform-specific code paths that `analyze` alone won't always catch project-wide.

### Pending items (require user action — do NOT attempt autonomously)

| # | Action | Blocker |
|---|---|---|
| 1 | Confirm whether Play App Signing is enrolled; if not, consider enrolling | Play Console |
| 2 | Set build watch paths on the `hmr-flutter-bot` Worker so docs/tooling commits stop shipping production deploys | Cloudflare dashboard |
| 3 | Confirm the Worker's dashboard build command actually runs `flutter build web --release` — if it is ever cleared, a deploy blanks `hmrbot.com/ai` | Cloudflare dashboard |

---

## Key Decisions and Rationale

| Decision | Rationale |
|---|---|
| `minSdk = flutter.minSdkVersion` | Flutter auto-migrates any lower hard-coded value on every build; all plugins support the engine minimum. |
| `compileSdk = targetSdk = 36` | Play Store target-API requirement. |
| `allowBackup = false` | Conversations are personal; Android Auto Backup must not exfiltrate them. |
| Aliyun mirrors in `settings.gradle.kts` | The development team is in Iran; `dl.google.com` and Maven Central are not reliably reachable. |
| Jalali (Shamsi) calendar for all dates | The product is built for the Iranian market; Gregorian timestamps would confuse users. |
| Conversation **list** is 100% on-device (no list-sync backend) | No list-sync infrastructure exists; the index/messages stay in SharedPreferences + SQLite. Server-side **memory** continuity only (Flowise `sessionId = sub` for signed-in users) — not list sync. Since `sub` is one session per user, a signed-in user's separate conversations share one Flowise memory; use `"${sub}:${conversationId}"` if per-conversation isolation is ever needed (at the cost of cross-device continuity). UI copy must not claim full cross-device sync. |
| Error messages not persisted to SQLite | Error bubbles are ephemeral UI state. Persisting them would require a schema migration and add no user value; reloading a conversation shows clean history. |
| `BackdropFilter` only on static surfaces | Per-bubble blur tanks frame rate on mid-range Android. Semi-transparent solid fills achieve the glass aesthetic at a fraction of the GPU cost. |
| UUID v4 for all IDs | Collision-free across devices without a server; replaces previous millisecond-timestamp IDs which could collide during rapid creation. |
| `authenticationEvents` stream as `_user`'s single source of truth (not per-call return values) | Required for web (the GIS button's click result can only ever arrive via the stream), and works identically on native since the package synthesizes the same events from `authenticate()`/`attemptLightweightAuthentication()` — one code path instead of a platform-specific special case. |

---

## Privacy Policy

URL: `https://hmrbot.com/privacy`

Wired as constant `_kPrivacyPolicyUrl` in `lib/screens/conversations_screen.dart`.
The sidebar drawer tile "حریم خصوصی" opens this URL in the device browser via `url_launcher`.
