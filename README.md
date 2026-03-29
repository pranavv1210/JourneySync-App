<div align="center">

<h1 style="display: flex; align-items: center; justify-content: center; gap: 12px; margin: 0; line-height: 1.1;">
  <img src="assets/logo.png" alt="JourneySync Logo" width="40" style="display: block;" />
  <span style="display: block;">JourneySync - Group Ride & Safety App</span>
</h1>

<p>
  <a href="./CONTRIBUTING.md">Contributing</a> •
  <a href="./LICENSE">MIT License</a> •
  <a href="./SECURITY.md">Security</a>
</p>

<img src="assets/banner.png" alt="JourneySync Banner" width="85%" />

<br/>

<img alt="Flutter" src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" />
<img alt="Dart" src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" />
<img alt="Supabase" src="https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white" />
<img alt="Auth0" src="https://img.shields.io/badge/Auth0-111827?style=for-the-badge&logo=auth0&logoColor=white" />
<img alt="OpenStreetMap" src="https://img.shields.io/badge/OpenStreetMap-7EBC6F?style=for-the-badge&logo=openstreetmap&logoColor=white" />
<img alt="Android" src="https://img.shields.io/badge/Android-34A853?style=for-the-badge&logo=android&logoColor=white" />
<img alt="iOS" src="https://img.shields.io/badge/iOS-111827?style=for-the-badge&logo=apple&logoColor=white" />

</div>

---

JourneySync is a production-oriented motorcycle group ride app focused on real-time coordination and rider safety.

## Quick Links
- [Features](#features)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Setup](#setup)
- [Environment Values](#environment-values)
- [iOS Notes](#ios-notes)

## Features
- Auth0-based login flow for new and existing riders
- Supabase-backed user profile storage (name, bike, avatar)
- Ride creation, lobby, and nearby active ride discovery
- Live ride map with participant context
- SOS alert workflow for emergency response
- Ride completion summary
- Weather info on home screen

## Architecture
- **Client**: Flutter (Dart)
- **Backend**: Supabase (Postgres + Storage)
- **Auth**: Auth0 Universal Login
- **Maps**: `flutter_map` + OpenStreetMap tiles
- **Location**: `geolocator`
- **Local state**: `shared_preferences`

## Project Structure
```text
lib/
  main.dart
  splash_screen.dart
  login_screen.dart
  home_screen.dart
  create_ride_screen.dart
  nearby_rides_screen.dart
  map_screen.dart
  ride_lobby_screen.dart
  live_ride_screen.dart
  sos_alert_screen.dart
  ride_summary_screen.dart
  settings_screen.dart

  auth_service.dart
  ride_service.dart
  supabase_service.dart
  weather_service.dart
```

## Setup
1. Install dependencies:
```bash
flutter pub get
```

2. Run in debug:
```bash
flutter run --dart-define-from-file=dart_defines.local.json
```

3. Build Android APK:
```bash
flutter build apk --release --dart-define-from-file=dart_defines.local.json
```

4. Create and publish an Android release manually when you are ready:
```powershell
.\scripts\release.ps1 -Version 1.0.2
```
This command updates the app version, builds the signed Android APK, creates a git tag, pushes the branch and tag, uploads the APK to GitHub Releases, and publishes the release.

## Environment Values
This project expects runtime `--dart-define` values:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `AUTH0_DOMAIN`
- `AUTH0_CLIENT_ID`
- `AUTH0_SCHEME` (optional, defaults to `journeysync`)
- `SUPABASE_AVATAR_BUCKET` (optional, defaults to `avatars`)

Example:
```bash
flutter run \
  --dart-define=SUPABASE_URL=YOUR_URL \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=AUTH0_DOMAIN=YOUR_TENANT.REGION.auth0.com \
  --dart-define=AUTH0_CLIENT_ID=YOUR_AUTH0_CLIENT_ID \
  --dart-define=AUTH0_SCHEME=journeysync
```

## Android Signing
For release signing, create `android/key.properties` from `android/key.properties.example` and point it to your keystore file.

For automated local releases:
- Install and log in to GitHub CLI with `gh auth login`
- Keep `android/key.properties` configured locally
- Keep `dart_defines.local.json` present locally

## iOS Notes
Already configured permission keys in `ios/Runner/Info.plist`:
- `NSLocationWhenInUseUsageDescription`
- `NSPhotoLibraryUsageDescription`
- `NSPhotoLibraryAddUsageDescription`
- `NSCameraUsageDescription`

For distribution, complete signing/provisioning in Xcode.

## Security
- Do not commit secrets (`service_role`, client secrets, keystore passwords).
- Keep only public client-side keys in app runtime config.

## License
MIT. See [LICENSE](./LICENSE).

