# Nori — native iOS personal assistant

Nori is a SwiftUI assistant for students and working professionals. Typed or spoken requests become tasks, calendar blocks, meeting invitations, and email actions that remain visible for approval.

## Architecture

- **App:** SwiftUI, native audio, WebRTC, Keychain, EventKit, and Google OAuth PKCE.
- **Text AI:** Swift calls OpenAI `/v1/chat/completions` directly with `URLSession`.
- **Voice AI:** Swift mints an OpenAI Realtime client secret and connects directly using native WebRTC.
- **Actions:** Swift calls Google Calendar and Gmail APIs directly after native Google sign-in.
- **Infrastructure:** no FastAPI, Node, Python, Docker, LiteLLM, or custom WebSocket server.

The only package dependency is `stasel/WebRTC`, which provides the native iOS WebRTC implementation required for low-latency Realtime audio.

## Requirements

- macOS with Xcode 16 or newer
- iOS 17 or newer
- OpenAI project API key with access to the configured text and Realtime models
- Apple development team for physical-device builds

## Run Nori

1. Open `Nori.xcodeproj` in Xcode and allow Swift Package Manager to resolve `stasel/WebRTC`.
2. Select the **Nori** target and choose your team under **Signing & Capabilities**.
3. Run on an iPhone Simulator or connected iPhone.
4. Open **You → OpenAI Access**, enter your personal OpenAI project key, and save it.
5. Open the Nori tab and tap the microphone.

The key is stored in the device Keychain and requests go directly from the app to OpenAI. Do not embed a shared key in source code, build settings, or a distributed App Store binary.

## Connect Google

1. In Google Cloud Console, enable **Google Calendar API** and **Gmail API**.
2. Configure the OAuth consent screen and create an **iOS OAuth client** for Nori’s bundle identifier.
3. Set target build setting `NORI_GOOGLE_CLIENT_ID` to the generated client ID.
4. Set `NORI_GOOGLE_REDIRECT_SCHEME` to Google’s reversed client ID, such as `com.googleusercontent.apps.123456789-abc`.
5. Run Nori and choose **You → Google Workspace → Connect**.

Nori uses OAuth Authorization Code with PKCE and stores refresh credentials in Keychain. It requests only `calendar.events` and `gmail.send` scopes. Gmail scope verification is normally required before public distribution.

## Behavior

- Local tasks can run automatically when autonomy is enabled.
- Calendar events, invitations, and email sends require an explicit action-card tap.
- With Google connected, approval writes directly to Google Calendar or Gmail.
- Without Google, calendar approval uses EventKit and email approval opens a Mail draft.
- Without an OpenAI key, typed requests use the built-in local planner; Realtime voice requires OpenAI.

## Validate

```bash
swiftc -parse $(find Nori -name '*.swift' -print)
plutil -lint Nori/Resources/Info.plist Nori.xcodeproj/project.pbxproj
xcodebuild -project Nori.xcodeproj -scheme Nori -sdk iphonesimulator build CODE_SIGNING_ALLOWED=NO
```

The final command requires the full Xcode application. See `PRODUCTION.md` before shipping.
