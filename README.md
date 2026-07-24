# Nori — native iOS personal assistant

Nori is a native SwiftUI app for students and working professionals. It turns spoken or typed requests into tasks, focus blocks, meeting invites, and reviewable email actions.

## Requirements

- macOS with Xcode 16 or newer
- iOS 17 or newer
- An Apple development team for device builds
- Node.js 20 or newer only when running the optional backend

## Run the iOS app

1. Open `Nori.xcodeproj` in Xcode.
2. Select the **Nori** target and choose your development team under **Signing & Capabilities**.
3. Choose an iPhone simulator or connected iPhone.
4. Press **Run**.

The app works immediately with its local natural-language planner. Microphone, speech recognition, and calendar permissions are requested only when those features are used.

## Native capabilities

- SwiftUI interface with Dynamic Type, VoiceOver labels, native tab navigation, sheets, alerts, and keyboard behavior.
- Live voice requests through `Speech` and `AVFoundation`.
- Native calendar writes through `EventKit`. Events sync to Google Calendar when the user's Google account is enabled in iOS Calendar settings.
- Secure remote AI planning through `URLSession`, with a useful local fallback.
- Direct Google Calendar and Gmail execution through the optional backend.
- Explicit approval cards before meetings, emails, or external calendar changes.
- One-tap in-app demo covering every action type.

## Connect the backend

The dependency-free Node server uses the OpenAI Responses API, Google Calendar API, and Gmail API.

```bash
cp .env.example .env
# Add your server credentials to .env
npm run server:env
```

In Xcode, edit the **Nori** scheme and add these environment variables to **Run → Arguments**:

```text
NORI_ASSISTANT_URL=http://127.0.0.1:8787/assistant
NORI_EXECUTE_URL=http://127.0.0.1:8787/execute
NORI_APP_TOKEN=
NORI_USER_ID=local-ios-user
```

For Release/TestFlight builds, set the user-defined build settings `NORI_ASSISTANT_URL` and `NORI_EXECUTE_URL` to deployed HTTPS endpoints. Enter `NORI_APP_TOKEN` in Nori’s **Settings → Backend Access** screen; it is stored in the device Keychain instead of the app bundle. Use a LAN URL only for local development. Keep OpenAI and Google credentials on the server.

## Validate

```bash
npm test
node --check server/index.mjs
swiftc -parse $(find Nori -name '*.swift' -print)
plutil -lint Nori/Resources/Info.plist Nori.xcodeproj/project.pbxproj
xcodebuild -project Nori.xcodeproj -scheme Nori -sdk iphonesimulator build CODE_SIGNING_ALLOWED=NO
```

The final `xcodebuild` command requires the full Xcode application, not only Command Line Tools.

## Release readiness

The app includes protected local persistence, Keychain credentials, bounded history, explicit external-action approval, timeout/error handling, an App Store icon, and an Apple privacy manifest. The server includes strict input limits, constant-time token authentication, rate limiting, request IDs, safe production errors, health/readiness probes, upstream timeouts, and graceful shutdown.

See `PRODUCTION.md` before shipping. The bundled backend is designed for one personal Google account on one server instance. A public multi-user service still requires real user authentication, per-user OAuth storage, durable distributed idempotency, abuse controls, and a privacy policy.
