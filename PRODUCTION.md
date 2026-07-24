# Production checklist

## iOS release

- Install current Xcode, select an Apple development team, and replace `com.nori.assistant` with an App Store Connect bundle identifier.
- Set Release build settings `NORI_ASSISTANT_URL` and `NORI_EXECUTE_URL` to HTTPS endpoints. Never place API keys or the backend token in build settings, source control, or `Info.plist`.
- Enter the backend access token in the app’s Settings screen on each device. Nori stores it as a device-only Keychain item.
- Confirm the declarations in `Nori/Resources/PrivacyInfo.xcprivacy` against the final analytics, crash reporting, and backend data-retention policy.
- Add a public privacy policy and support URL in App Store Connect. Explain that requests and selected planning context are sent to the configured AI backend.
- Test microphone, Speech Recognition, Calendar, Mail, Dynamic Type, VoiceOver, offline behavior, and denied permissions on physical devices.
- Archive with Release configuration, run Xcode’s validation, upload to TestFlight, and complete App Store privacy and encryption questionnaires.

## Backend deployment

1. Run Node.js 20 or newer behind an HTTPS reverse proxy or managed container platform.
2. Set `NODE_ENV=production`, `OPENAI_API_KEY`, and a random `NORI_APP_TOKEN` of at least 32 characters. Generate one with `openssl rand -hex 32`.
3. Set Google OAuth credentials only when direct Calendar/Gmail execution is required. Restrict the OAuth client, minimize scopes, and complete Google verification before distributing to other users.
4. Bind publicly only inside a protected container/network, terminate TLS at the edge, and keep `.env` outside source control.
5. Monitor structured stderr logs and probe `/health` for liveness and `/ready` for readiness.
6. Rotate all secrets, rehearse rollback, and back up OAuth credentials before launch.

## Scaling boundary

The included server intentionally supports one personal Google account and one process. Before offering Nori as a multi-user service, replace the shared token with user authentication, encrypt OAuth tokens per user, move rate limits and idempotency receipts to a durable shared store, add audit logs and token revocation, and document retention/deletion controls.
