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
