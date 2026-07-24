# Production checklist

## iOS release

- Install current Xcode, select an Apple development team, and replace `com.nori.assistant` with the App Store Connect bundle identifier.
- Configure the Google iOS client ID and reversed redirect scheme for the final bundle identifier.
- Complete Google OAuth verification for Calendar and Gmail scopes before external distribution.
- Confirm `Nori/Resources/PrivacyInfo.xcprivacy` against the final analytics, crash reporting, AI retention, and Google data-use policy.
- Publish privacy and support URLs. Explain that microphone audio and selected planning context are sent directly to OpenAI.
- Test Realtime interruptions, headphones, denied permissions, key removal, Google token expiry, offline behavior, Dynamic Type, and VoiceOver on physical devices.
- Test EventKit change delivery, background refresh scheduling, conflict de-duplication, daily notifications, and App Intent discovery on physical devices.
- Archive with Release, run Xcode validation, upload to TestFlight, and complete Apple privacy and encryption questionnaires.

## OpenAI key boundary

The current direct-client design is appropriate for a personal or internal bring-your-own-key app: each user enters their own OpenAI project key, which Nori stores in Keychain.

Do not preinstall one shared OpenAI key in a public binary. iOS applications cannot securely conceal a bundled secret. A public consumer release needs authenticated server-side ephemeral-token issuance, budget and rate controls, abuse monitoring, and key revocation. OpenAI’s Realtime guidance likewise requires standard API keys to stay on a trusted server for public client applications.

## Google security

- Keep OAuth tokens only in Keychain and revoke them on disconnect or account removal.
- Keep scopes limited to `calendar.events` and `gmail.send` unless a reviewed feature requires more.
- Treat Calendar attendees and email content as sensitive user data; avoid analytics payloads containing either.
- Provide account deletion and token-revocation instructions in the privacy policy.

## Monitoring boundary

The included app detects conflicts when calendars refresh in the foreground, after EventKit change notifications, and during opportunistic iOS background refresh. iOS does not guarantee continuous background execution. A public release promising immediate alerts while the app is closed needs Google Calendar push channels, trusted server processing, APNs, durable de-duplication, and revocation handling.

## Release boundary

The repository provides a functional personal-device build. Public launch still requires production monitoring, legal/privacy review, abuse controls, authenticated OpenAI token issuance, and verified Google OAuth consent.
