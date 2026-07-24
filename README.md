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

Use a LAN or deployed HTTPS URL on a physical iPhone. Keep `OPENAI_API_KEY`, Google client secrets, and refresh tokens on the server only.

## Validate

```bash
npm test
plutil -lint Nori/Resources/Info.plist Nori.xcodeproj/project.pbxproj
xcodebuild -project Nori.xcodeproj -scheme Nori -sdk iphonesimulator build CODE_SIGNING_ALLOWED=NO
```

The final `xcodebuild` command requires the full Xcode application, not only Command Line Tools.

## Production hardening

The included backend is suitable for a single-user prototype. A multi-user deployment must add user authentication, per-user encrypted OAuth storage, durable idempotency receipts, token revocation, and production observability.
