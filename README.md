# HMR — همر

**HMR (همر)** is a Persian-language AI chatbot for the Iranian mobile market, delivering intelligent hardware recommendations across five product categories: **Phone · Laptop · Tablet · Earphones · Accessories**.

Built with Flutter (Android-first), it features a glassmorphism UI, full RTL support, Jalali calendar dates, 100 % local storage, and a hardened production-ready architecture.

---

## Features

- **AI-powered recommendations** via Flowise on a dedicated VPS
- **Five pillars**: Phone · Laptop · Tablet · Earphones · Accessories
- **Persistent conversation history** — multi-session SQLite storage, 100 % on-device
- **Google Sign-In** (Firebase-free; direct Google OAuth)
- **Offline detection** — immediate user feedback before attempting any network call
- **Resilient API layer** — up to 2 automatic retries with 1 s / 2 s backoffs for transient failures
- **Error bubbles** with a one-tap retry button for recoverable failures
- **Markdown rendering** in AI responses — bold, lists, code blocks, hyperlinks
- **External link handling** — AI-response links open in the device browser
- **Price disclaimer strip** — users are always reminded to verify prices before purchase
- **Ghost-conversation cleanup** — empty sessions created by a back-press are deleted automatically
- **Confirmed destructive actions** — delete and clear-history flows require explicit confirmation
- **Jalali (Shamsi) dates** — conversation timestamps use the Persian calendar
- **Sentry integration** — opt-in crash reporting via `--dart-define`
- **Release error boundary** — friendly Persian screen replaces Flutter's red crash widget in production
- **Persian RTL UI** — Vazirmatn typeface, dark navy / cyan glassmorphism design system

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.44.2 · Dart 3.12.2 |
| Android build | AGP 9.0.1 · compileSdk / targetSdk 36 · minSdk 24 |
| AI backend | [Flowise](https://github.com/FlowiseAI/Flowise) — self-hosted VPS |
| Auth | `google_sign_in ^6.2.1` (no Firebase dependency) |
| HTTP | `http ^1.2.0` |
| External links | `url_launcher ^6.3.0` (opens AI-response links in the device browser) |
| Local storage | `sqflite ^2.3.3` (messages) · `shared_preferences ^2.2.2` (conversation index) |
| Web storage backend | `sqflite_common_ffi_web ^0.4.5` (IndexedDB + `sqlite3.wasm`; web only, conditional import) |
| Paths | `path ^1.9.0` (SQLite database file location) |
| Markdown | `flutter_markdown_plus ^1.0.7` |
| Connectivity | `connectivity_plus ^6.1.4` |
| ID generation | `uuid ^4.5.1` |
| Error tracking | `sentry_flutter 9.0.0` (opt-in via dart-define) |
| State management | `provider ^6.1.1` |
| Localization | `intl ^0.20.2` · `flutter_localizations` (fa-IR locale, Jalali & number formatting) |
| Fonts | Vazirmatn (Persian UI) · SpaceGrotesk Variable (Latin / brand) |
| Dev tooling | `flutter_lints ^6.0.0` · `flutter_launcher_icons ^0.14.3` · `flutter_native_splash ^2.4.4` |

---

## Project Structure

```
lib/
├── main.dart                        App entry: Sentry init, error boundary, providers, locale
├── theme/
│   └── app_theme.dart               Design tokens — colors, gradients, text styles
├── providers/
│   ├── auth_provider.dart           Google Sign-In state machine
│   ├── chat_provider.dart           Per-session message list, API calls, retry logic
│   └── conversations_provider.dart  Conversation index — SharedPreferences + SQLite
├── screens/
│   ├── conversations_screen.dart    History list, sidebar drawer, new-chat FAB
│   └── chat_screen.dart             Chat surface, composer, clear-history action
├── services/
│   └── api_service.dart             Flowise REST client — offline guard, retry loop
├── database/
│   └── chat_database.dart           SQLite singleton — messages schema and CRUD
├── models/
│   ├── conversation_model.dart      Conversation index entry (JSON-serialisable)
│   └── message_model.dart           Message (uuid id, role, text, timestamp, isError)
├── widgets/
│   ├── chat_bubble.dart             Markdown AI bubble + neon user bubble + error state
│   ├── confirm_dialog.dart          Reusable dark-glass confirmation dialog
│   ├── price_disclaimer.dart        Amber glassmorphism disclaimer strip
│   ├── hmr_avatar.dart              Animated HMR orb
│   └── hmr_background.dart         Glassmorphism radial gradient background
└── utils/
    └── jalali.dart                  Gregorian → Shamsi (Jalali) date conversion

android/
├── app/
│   ├── build.gradle.kts             compileSdk 36, minSdk 24, signing config
│   ├── proguard-rules.pro           Keep rules for GMS, sqflite, shared_preferences
│   └── src/main/
│       └── AndroidManifest.xml      Permissions, <queries> for url_launcher + GMS
└── settings.gradle.kts              AGP 9.0.1; Aliyun mirrors for restricted networks
```

---

## Getting Started

### Prerequisites

- Flutter 3.44.2 (or a later compatible release)
- Dart 3.12.2+
- Android Studio or VS Code with the Flutter extension
- A running Flowise instance with your chatflow configured

### Clone and install

```bash
git clone https://github.com/wikigoo/HMR-App.git
cd HMR-App
flutter pub get
```

### Build-time variables

All secrets are injected at compile time via `--dart-define`. Nothing is hard-coded or committed to the repository.

| Variable | Required | Description |
|---|---|---|
| `HMR_API_TOKEN` | **Yes** | Bearer token for the Flowise prediction endpoint |
| `SENTRY_DSN` | No | Sentry project DSN; omit entirely to disable crash reporting |

### Debug run

```bash
flutter run --dart-define=HMR_API_TOKEN=<your-token>
```

### Release build (Android App Bundle)

```bash
flutter build appbundle --release \
  --dart-define=HMR_API_TOKEN=<your-token> \
  --dart-define=SENTRY_DSN=<your-dsn>
```

Signing credentials are read from environment variables in CI (`HMR_KEY_ALIAS`, `HMR_KEY_PASSWORD`, `HMR_STORE_PASSWORD`, `HMR_KEYSTORE_PATH`) or from `android/key.properties` for local builds (gitignored).

---

## Network Setup for Developers in Iran

`dl.google.com` and Maven Central are not reliably accessible from Iran. The build requires an Aliyun Maven mirror because `sqflite_android` hardcodes `google()` in its buildscript classpath.

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

---

## API Architecture

The app communicates with a self-hosted Flowise instance over HTTPS.

**Endpoint:** `POST https://srv.hmrbot.com/api/v1/prediction/<chatflow_id>`

**Request body:**
```json
{
  "question": "<user message>",
  "streaming": false,
  "overrideConfig": { "sessionId": "<uuid>" }
}
```

**Error handling strategy:**

| Condition | Classification | Behaviour |
|---|---|---|
| No network connectivity | Terminal | Immediate `ApiException` — no HTTP call made |
| `TimeoutException`, `ClientException` | Transient | Retry up to 2 times (1 s, 2 s backoff) |
| HTTP 502 / 503 / 504 | Transient | Retry up to 2 times (1 s, 2 s backoff) |
| HTTP 401 / 403 | Terminal | `ApiException` — auth error message shown |
| HTTP 500, malformed JSON | Terminal | `ApiException` — error message shown |

All errors surface as Persian-language error bubbles in the chat UI with a one-tap "تلاش مجدد" (retry) button.

---

## Storage

| Data | Backend | Key / Schema |
|---|---|---|
| Conversation index | `SharedPreferences` | `conversations_index` — JSON array of `ConversationModel` |
| Messages | SQLite `messages` table | Columns: `id`, `conv_id`, `role`, `text`, `ts`; indexed on `(conv_id, ts)` |

All data is stored exclusively on the user's device. There is no sync backend. Uninstalling the app permanently deletes all conversations.

---

## Security Notes

- The API token is injected at compile time; never stored in source or committed to git
- `allowBackup="false"` prevents Android Auto Backup from extracting local chat data
- `android/key.properties` and keystore files are gitignored
- `google-services.json` is gitignored
- ProGuard / R8 keep rules cover GMS, sqflite, shared_preferences, and url_launcher
- `<queries>` in the manifest declares only the `https` VIEW intent and the GMS package

**Known technical debt:** The Flowise API token currently resides in the compiled binary via `--dart-define`. The planned remediation is a thin HTTPS reverse proxy on the VPS that holds the token server-side and forwards requests to Flowise. Until that proxy is deployed, `--dart-define` is the least-bad approach — it keeps the token out of source control while keeping the app functional.

---

## Privacy

Privacy policy: **https://hmrbot.com/privacy**

All conversation data is stored exclusively on the user's device. HMR does not transmit, store, or process any personally identifiable information on its own infrastructure beyond what Flowise processes to generate a response to the user's query.

---

## Contributing

### Branch strategy

| Pattern | Purpose |
|---|---|
| `main` | Stable, release-ready code |
| `feat/<description>` | New features |
| `fix/<description>` | Bug fixes and hardening work |

### Commit guidelines

- One logical change per commit
- Never force-push to published branches; never amend published commits
- Run `flutter analyze` (must report zero issues) before opening a pull request

---

## Pending Work (requires action outside this repository)

| # | Task | Blocker |
|---|---|---|
| 1 | Rotate signing keystore; purge old keystore from git history; enroll in Play App Signing | Needs `keytool` + Play Console access |
| 2 | Deploy VPS reverse proxy so the API token is removed from the client binary | Needs VPS SSH + server deployment |
| 3 | Register SHA-1 / SHA-256 fingerprints in Google Cloud Console for production OAuth | Needs Google Cloud login |

---

## License

Proprietary. All rights reserved. Contact the repository owner for licensing inquiries.
