# JourneySync iOS Beta Release

JourneySync iOS distribution must go through Apple tooling. A release IPA cannot
be built on Windows; Flutter iOS release builds require macOS, Xcode, and an
Apple Developer Program account.

## Requirements

- macOS with latest stable Xcode
- Apple Developer Program membership
- App Store Connect app record for JourneySync
- Bundle ID, signing certificate, and provisioning profile configured in Xcode

## Build And Upload

The repo includes a manual GitHub Actions workflow:

- Workflow: `Build Flutter Release Artifacts`
- Default run: builds Android APK and unsigned iOS `Runner.app` on a macOS runner
- Signed run: enable `build_ios_signed` and add the secrets below

Unsigned iOS artifacts are useful for checking that the iOS project compiles,
but they cannot be installed by beta testers and cannot be uploaded to
TestFlight.

## GitHub Secrets For Signed IPA

Add these in GitHub repository settings:

- `IOS_CERTIFICATE_BASE64`: base64 encoded Apple Distribution `.p12`
- `IOS_CERTIFICATE_PASSWORD`: password for the `.p12`
- `IOS_PROVISIONING_PROFILE_BASE64`: base64 encoded App Store provisioning profile
- `IOS_KEYCHAIN_PASSWORD`: any strong temporary CI keychain password
- `IOS_TEAM_ID`: Apple Developer Team ID
- Optional app env: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SENTRY_DSN`

On macOS you can create base64 values with:

```bash
base64 -i certificate.p12 | pbcopy
base64 -i profile.mobileprovision | pbcopy
```

Then run the GitHub Actions workflow manually and set `build_ios_signed` to
`true`.

## Local macOS Build

```bash
flutter clean
flutter pub get
flutter build ipa --release
```

Then upload the generated archive from Xcode Organizer or Transporter to App
Store Connect and enable TestFlight testing.

## Connect Email To TestFlight

When TestFlight is ready, set this Supabase Edge Function secret:

```bash
supabase secrets set IOS_BETA_URL="https://testflight.apple.com/join/YOUR_CODE"
supabase functions deploy send-beta-welcome-email
```

iOS beta signups already send the `platform: ios` value to Supabase and the
welcome email function. Once `IOS_BETA_URL` points to TestFlight, iOS users will
receive that link automatically.
