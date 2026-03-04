<div align="center">

# JourneySync - Group Ride & Safety App

<p>
  <a href="./CONTRIBUTING.md">Contributing</a> •
  <a href="./LICENSE">MIT License</a> •
  <a href="./SECURITY.md">Security</a>
</p>

<img src="assets/banner.png" alt="JourneySync Banner" width="100%" />

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
flutter run
```

3. Build Android APK:
```bash
flutter build apk --release
```

## Environment Values
This project expects runtime `--dart-define` values:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `PHONE_EMAIL_CLIENT_ID` (kept for compatibility in current config)

Example:
```bash
flutter run \
  --dart-define=SUPABASE_URL=YOUR_URL \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=PHONE_EMAIL_CLIENT_ID=YOUR_CLIENT_ID
```

## Android Signing
For release signing, create `android/key.properties` from `android/key.properties.example` and point it to your keystore file.

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
