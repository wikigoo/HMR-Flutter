# CLAUDE.md — HMR / همر Flutter App

Instructions for Claude Code when working in this repository.

---

## Project overview

**HMR (همر)** is a Persian-language AI chatbot for the Iranian mobile market.
It provides smart hardware recommendations across five pillars: phone · laptop · tablet · earphones · accessories.

- **Frontend:** Flutter (Android-first), Astro + Cloudflare for the web landing page
- **AI backend:** Flowise on a VPS at 82.22.175.236
- **Auth:** Google Sign-In (firebase-less; direct Google OAuth)
- **Storage:** SQLite (conversations) + SharedPreferences (settings) — 100 % local, no sync backend

---

## Non-negotiable product invariants

1. **Language / direction:** UI is Persian (Farsi), RTL, Vazirmatn font. Never change language, text direction, or font family.
2. **Branding:** Dark navy/cyan color palette (`AppTheme`). Do not alter brand colors or the HMR orb.
3. **Five pillars:** Phone · Laptop · Tablet · Earphones · Accessories — do not remove or rename.
4. **Price disclaimer:** The app must never display a specific price as final. It must always suggest users verify prices at point of sale.
5. **Honesty boundary:** The assistant must never claim capabilities it does not have (e.g., cross-device sync does not exist; do not claim it).
6. **Flowise endpoints:** Never change `chatflow_id`, Flowise base URL, or session-ID / handle naming in `api_service.dart`. Any API-layer change requires a live VPS proxy first (see Security below).

---

## Architecture

```
lib/
  main.dart                   App entry, providers, locale (fa)
  theme/app_theme.dart        All colors, text styles, gradients
  providers/
    auth_provider.dart        Google Sign-In state
    chat_provider.dart        Per-conversation message list + Flowise calls
    conversations_provider.dart  SQLite conversation index
  screens/
    conversations_screen.dart History list + sidebar drawer
    chat_screen.dart          Main chat surface
  services/
    api_service.dart          Flowise REST client (DO NOT change endpoints)
    database_service.dart     SQLite init + CRUD
  models/
    conversation_model.dart
    message_model.dart
  widgets/
    chat_bubble.dart          Markdown-rendered message bubbles
    hmr_avatar.dart           Animated HMR orb
    hmr_background.dart       Glassmorphism gradient background
  utils/jalali.dart           Gregorian → Shamsi date conversion

android/
  app/build.gradle.kts        compileSdk=36, targetSdk=36, minSdk=flutter.minSdkVersion (=24 on Flutter 3.44.2)
  app/src/main/AndroidManifest.xml
  settings.gradle.kts         AGP 9.0.1; Aliyun mirrors for restricted networks
```

---

## Build setup

### Flutter version
Flutter 3.44.2 · Dart 3.12.2 · AGP 9.0.1

### Aliyun mirror (required on restricted networks)
Create `~/.gradle/init.d/aliyun-mirror.gradle` with:
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
This is required because `sqflite_android 2.4.3` hardcodes `google()` in its buildscript classpath,
which resolves to `dl.google.com` — inaccessible from Iran without this redirect.

### Release build
```
flutter build appbundle --release
```
Signing config is read from env vars (`HMR_KEY_ALIAS`, `HMR_KEY_PASSWORD`, `HMR_STORE_PASSWORD`, `HMR_KEYSTORE_PATH`) for CI,
or from `android/key.properties` (gitignored) for local builds.

---

## Security rules (absolute)

- **Never** print, log, or commit any secret: tokens, keystore passwords, `key.properties`, `google-services.json`.
- **Never** commit the keystore file. It must stay in `android/key.properties` (gitignored) or be passed via env vars in CI.
- The Flowise API token lives in the client (`api_service.dart`) — this is a known technical debt. Do NOT move it until a VPS proxy is in place. Changing the token location without a proxy would break the app immediately.
- The VPS proxy spec (when ready): a thin HTTPS proxy at `82.22.175.236` that holds the token server-side and forwards requests to Flowise. After the proxy is live, update `api_service.dart` to point to the proxy URL (no token in client).

---

## Workflow

### Branch strategy
- All fixes on feature branches: `fix/<description>` or `feat/<description>`
- One commit per logical change
- Never force-push; never amend published commits

### Verification
After every code change:
1. `flutter analyze` — must be clean (zero issues)
2. For Android-affecting changes: `flutter build appbundle --release`

### Pending user-action items (do NOT attempt autonomously)
| # | Action | Why blocked |
|---|--------|-------------|
| 1b | Rotate signing keystore; purge from git history; enroll Play App Signing | Needs keytool + Play Console + remote push |
| 2 | Deploy VPS proxy so API token leaves client | Needs VPS SSH + server deployment |
| 4 | Register SHA-1/SHA-256 fingerprints in Google Cloud Console | Needs Google Cloud login |

---

## Key decisions & rationale

| Decision | Rationale |
|----------|-----------|
| `minSdk = flutter.minSdkVersion` (= 24) | Flutter 3.44.2 auto-migrates any lower hardcoded value on every build; `flutter.minSdkVersion = 24` is the engine minimum. All plugins support 24. |
| `compileSdk = 36`, `targetSdk = 36` | Play Store requirement from 31 Aug 2026. |
| `allowBackup = false` | User data is local and personal; backup disabled to protect privacy. |
| Aliyun mirrors in `settings.gradle.kts` | Developers are in Iran; `dl.google.com` and `maven.central.org` are not reliably accessible. |
| Shamsi (Jalali) calendar for dates | Product is for the Iranian market; Gregorian dates are confusing to users. |
| Storage 100% local (no sync) | No sync backend exists. The sidebar copy reflects this honestly. |

---

## Privacy policy

URL: `https://hmrbot.com/privacy`
Wired in `lib/screens/conversations_screen.dart` → `_kPrivacyPolicyUrl` constant.
The drawer "حریم خصوصی" tile opens this URL in the device browser.
