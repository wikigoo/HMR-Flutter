# CLAUDE.md — HMR / همر Flutter App

Instructions for Claude Code and any AI coding assistant working in this repository.

---

## Project Overview

**HMR (همر)** is a Persian-language AI chatbot for the Iranian mobile market. It delivers smart hardware recommendations across five product pillars: **Phone · Laptop · Tablet · Earphones · Accessories**.

| Concern | Detail |
|---|---|
| Frontend | Flutter 3.44.2, Android-first |
| AI backend | Flowise on a self-hosted VPS (`https://srv.hmrbot.com`) |
| Auth | Google Sign-In via **Google Identity Services** (`google_sign_in`) — Google Cloud project `ir-hmrbot-app`. **No Firebase Auth** — this repo has no `firebase_auth`/`firebase_core` dependency. |
| Storage | SQLite (messages) + SharedPreferences (conversation index) — 100 % on-device, no sync |
| Locale | Persian (Farsi), RTL, Jalali (Shamsi) calendar |

---

## Non-Negotiable Product Invariants

These rules must **never** be broken regardless of the task at hand.

1. **Language and direction:** The UI is Persian (Farsi), RTL, Vazirmatn font. Never change language, text direction, or font family.
2. **Branding:** Dark navy/cyan color palette defined in `AppTheme`. Do not alter brand colors or the HMR orb widget.
3. **Five pillars:** Phone · Laptop · Tablet · Earphones · Accessories — do not remove, rename, or reorder them.
4. **Price disclaimer:** The app must never present a specific price as definitive. Users must always be prompted to verify prices at the point of sale. The `PriceDisclaimer` widget implements this contract.
5. **Honesty boundary:** The AI assistant must never claim capabilities that do not exist. **Partial sync only:** since Phase 4 (2026-07-15), a *signed-in* user's Flowise conversation **memory** follows them across web and mobile (the Flowise `sessionId` is the Google `sub`). But the **conversation list is still 100% on-device** — there is **no list/history sync backend**. So do **not** claim full "cross-device sync" in UI copy; at most, "your signed-in chat continues across your devices."
6. **Flowise endpoints:** Never change `_chatflowId`, `_baseUrl`, or the `sessionId` **field/signature** in `api_service.dart`. (Phase 4 changed only the *value* the caller passes — `ChatProvider` sends `userId ?? conversationId` — `api_service.dart` itself is untouched.) Any modification to the API layer requires a live VPS reverse proxy to be deployed first (see Security section).

---

## Architecture

```
lib/
├── main.dart                        Entry point: SentryFlutter.init, error boundary,
│                                    MultiProvider, locale (fa-IR), RTL Directionality
├── theme/
│   └── app_theme.dart               Single source of truth for all design tokens:
│                                    colors (Color(0xAARRGGBB) — no withOpacity),
│                                    text styles, gradients, Markdown stylesheet
├── providers/                       ChangeNotifier state — Provider package
│   ├── auth_provider.dart           Google Sign-In state machine
│   ├── chat_provider.dart           Per-session messages, API dispatch, retry logic
│   └── conversations_provider.dart  Conversation index — SharedPreferences JSON array;
│                                    message CRUD delegated to ChatDatabase
├── screens/
│   ├── conversations_screen.dart    History list, sidebar drawer, new-chat FAB,
│                                    ghost-conversation cleanup on back-nav
│   └── chat_screen.dart             Chat surface, composer, clear-history confirm
├── services/
│   └── api_service.dart             Flowise REST client — offline guard, retry loop,
│                                    _TransientError / ApiException separation
├── database/
│   └── chat_database.dart           SQLite singleton via sqflite; messages table
├── models/
│   ├── conversation_model.dart      JSON-serialisable conversation record
│   └── message_model.dart           Message: uuid id, role, text, timestamp, isError flag
├── widgets/
│   ├── chat_bubble.dart             AI bubble (Markdown + error state) + user bubble
│   ├── confirm_dialog.dart          Reusable dark-glass confirmation dialog (title/body/label)
│   ├── price_disclaimer.dart        Amber glassmorphism disclaimer strip
│   ├── hmr_avatar.dart              Animated HMR orb
│   └── hmr_background.dart         Glassmorphism radial-gradient background
└── utils/
    └── jalali.dart                  Gregorian → Shamsi date formatting

android/
├── app/
│   ├── build.gradle.kts             compileSdk=36, targetSdk=36,
│   │                                minSdk=flutter.minSdkVersion (=24 on Flutter 3.44.2)
│   ├── proguard-rules.pro           Keep/dontwarn for GMS, sqflite, shared_preferences,
│   │                                lifecycle, custom-tabs, url_launcher
│   └── src/main/
│       └── AndroidManifest.xml      INTERNET permission, <queries> for https VIEW +
│                                    com.google.android.gms, allowBackup=false
└── settings.gradle.kts              AGP 9.0.1; Aliyun Maven mirrors
```

---

## Key Patterns and Contracts

### API layer (`api_service.dart`)

- `sendMessage()` checks connectivity **before** making any HTTP call.
- Retriable failures (`TimeoutException`, `ClientException`, HTTP 502/503/504) are wrapped in the private `_TransientError` class and retried up to **2 times** with **1 s / 2 s** backoffs.
- Terminal failures (HTTP 401/403/500, `FormatException`, empty body) are thrown as `ApiException` immediately — no retry.
- All error messages in `ApiException.message` are in Persian and are safe to display directly in the chat UI.

### Chat error state (`chat_provider.dart` + `message_model.dart`)

- `MessageModel` carries an `isError` flag. Error messages are **not persisted** to SQLite — they are ephemeral display-only objects.
- `ChatProvider._lastFailedText` stores the last failed user input so `retryLastMessage()` can replay the API call without re-adding a user bubble.
- `retryLastMessage()` removes the last error bubble before re-attempting.

### Confirmation dialogs (`confirm_dialog.dart`)

- All destructive actions (delete conversation, clear history) use `ConfirmDialog` — a parameterised dark-glass dialog returning `bool?` via `showDialog<bool>`.
- The confirm button always uses the red fill `Color(0x33FF5470)` / border `Color(0x66FF5470)` to signal danger. Do not soften these colors.

### Ghost-conversation cleanup (`conversations_screen.dart`)

- After returning from `ChatScreen`, `_openConversation()` queries `ChatDatabase.instance.fetchMessages(conv.id)`.
- If the message list is empty, `deleteConversation()` is called silently. This handles both new conversations the user immediately backed out of and any legacy empty records.

### Storage split

| Data | Backend | Notes |
|---|---|---|
| Conversation index | `SharedPreferences` → key `conversations_index` | JSON array of `ConversationModel`; sorted by `updatedAt` descending |
| Messages | SQLite `messages` table | `conv_id` + `ts` composite index; error messages excluded |

### Design tokens

All colors are in `AppTheme` as `Color(0xAARRGGBB)` literals. **Never** use `.withOpacity()` — Dart 3.x lint flags it. The Markdown stylesheet for AI bubbles is `AppTheme.markdown(context)`.

### Fonts

- `Vazirmatn` — all Persian UI text (`AppTheme.fontFa`)
- `SpaceGrotesk` — Latin brand text, "HMR" wordmark (`AppTheme.fontLatin`), single variable-font file

### Performance note on bubbles

`_GlassBubble` (inside `chat_bubble.dart`) intentionally uses **no** `BackdropFilter`. A real blur per bubble destroys frame rate on mid-range Android while the list scrolls. The heavy blur is reserved for static elements (composer bar, confirm dialog backdrop).

---

## Build Setup

### Flutter version

Flutter 3.44.2 · Dart 3.12.2 · AGP 9.0.1

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

Required because `sqflite_android 2.4.3` hardcodes `google()` in its buildscript classpath, which resolves to `dl.google.com` — inaccessible from Iran without this redirect.

### Build-time variables (`--dart-define`)

| Variable | Required | Purpose |
|---|---|---|
| `SENTRY_DSN` | No | Sentry project DSN; empty string disables Sentry silently |

> **API token:** The Flowise Bearer token is injected **server-side** by the nginx
> reverse proxy (`/etc/nginx/hmr-auth.conf`). The app sends no `Authorization` header;
> the client binary carries no secrets.

### Debug run

```bash
flutter run
```

### Release build

```bash
flutter build appbundle --release \
  --dart-define=SENTRY_DSN=<dsn>
```

Signing is read from env vars in CI (`HMR_KEY_ALIAS`, `HMR_KEY_PASSWORD`, `HMR_STORE_PASSWORD`, `HMR_KEYSTORE_PATH`) or from `android/key.properties` (gitignored) locally.

---

## Security Rules (Absolute)

- **Never** print, log, or commit any secret: tokens, keystore passwords, `key.properties`, `google-services.json`.
- **Never** commit the keystore file under any circumstances.
- The Flowise API token is injected **server-side** by the nginx reverse proxy (`hmr-auth.conf`). The app sends no `Authorization` header and the client binary carries no secrets. This was completed in July 2026.

---

## Workflow

### Branch strategy

- Feature work: `feat/<description>`
- Bug fixes and hardening: `fix/<description>`
- One logical change per commit; commit message explains *why*, not just *what*
- Never force-push to published branches; never amend published commits

### Verification gate

After every code change, before committing:

1. `flutter analyze` — must return **zero issues**
2. For any change touching `android/` or `pubspec.yaml`: `flutter build appbundle --release`

### Pending items (require user action — do NOT attempt autonomously)

| # | Action | Blocker |
|---|---|---|
| 1 | Rotate signing keystore; purge old keystore from git history; enroll Play App Signing | Needs `keytool` + Play Console + force-push to history |

> **Done 2026-07-14 — no longer pending:** registering the release SHA-1 in Google Cloud. Verified:
> the release keystore's SHA-1 (`2D:5B:3E:9A:…`) matches the Android OAuth client `…og77…` in project
> `ir-hmrbot-app`, and Android sign-in works. (Android OAuth clients take a SHA-1 only; a SHA-256 will
> be needed for Play App Signing when item 1 is done.)

## Auth notes (web)

Web sign-in uses the GIS **`renderButton`** widget, not `GoogleSignIn.signIn()` — the plugin
deprecated `signIn()` on the web and it can only synthesize a profile through the **People API**.
Session restore across page reloads depends on `signInSilently()`, which **must stay enabled on web**
(`AuthProvider.init()`). It defaults to `suppressErrors: true`, so a rejected FedCM/One-Tap prompt
resolves to `null` rather than throwing — it cannot loop. Skipping it on web is what previously broke
both session persistence *and* sign-in itself (by forcing the People API path while that API was
disabled in the Cloud project).

---

## Key Decisions and Rationale

| Decision | Rationale |
|---|---|
| `minSdk = flutter.minSdkVersion` (resolves to 24) | Flutter 3.44.2 auto-migrates any lower hard-coded value on every build. `24` is the engine minimum; all plugins support it. |
| `compileSdk = targetSdk = 36` | Play Store requirement from 31 August 2026. |
| `allowBackup = false` | Conversations are personal; Android Auto Backup must not exfiltrate them. |
| Aliyun mirrors in `settings.gradle.kts` | The development team is in Iran. `dl.google.com` and Maven Central are not reliably reachable. |
| Jalali (Shamsi) calendar for all dates | The product is built for the Iranian market; Gregorian timestamps would confuse users. |
| Conversation **list** is 100% on-device (no list-sync backend) | No list-sync infrastructure exists; the index/messages stay in SharedPreferences + SQLite. Phase 4 added server-side **memory** continuity only (Flowise `sessionId = sub` for signed-in users) — not list sync. Since `sub` is one session per user, a signed-in user's separate conversations share one Flowise memory (context can carry across them); use `"${sub}:${conversationId}"` if per-conversation isolation is ever needed (at the cost of cross-device continuity). UI copy must not claim full cross-device sync. |
| Error messages not persisted to SQLite | Error bubbles are ephemeral UI state. Persisting them would require a schema migration and add no user value; reloading a conversation shows clean history. |
| `BackdropFilter` only on static surfaces | Per-bubble blur tanks frame rate on mid-range Android. Semi-transparent solid fills achieve the glass aesthetic at a fraction of the GPU cost. |
| UUID v4 for all IDs | Collision-free across devices without a server; replaces previous millisecond-timestamp IDs which could collide during rapid creation. |

---

## Privacy Policy

URL: `https://hmrbot.com/privacy`

Wired as constant `_kPrivacyPolicyUrl` in `lib/screens/conversations_screen.dart`.
The sidebar drawer tile "حریم خصوصی" opens this URL in the device browser via `url_launcher`.
