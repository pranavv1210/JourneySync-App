# JourneySync

JourneySync is a motorcycle group ride coordination platform focused on ride discovery, pre-ride coordination, live group rides, and rider safety.

## Features

- Rider authentication and profile setup
- Motorcycle garage/profile details
- Ride creation with route preview, stops, max riders, and vehicle selection
- Nearby active ride discovery through Ride Radar
- Ride lobby with access code sharing, members, route context, and ride start controls
- Live ride map with participant context and location-aware ride state
- SOS and emergency-oriented ride safety workflows
- Ride history, summaries, notifications, Explore, and nearby essentials
- Simple in-app feedback collection

## Tech Stack

- Flutter
- Dart
- Supabase
- Auth0
- OpenStreetMap / `flutter_map`
- `geolocator`
- `shared_preferences`

## Project Structure

```text
lib/
  main.dart                 App bootstrap and Supabase initialization
  screens/                  Flutter app screens and flows
  services/                 Auth, Supabase, ride, tracking, weather, and app services
  models/                   Ride, member, route, location, and notification models
  coordinators/             Realtime, notification, and active ride coordinators
  widgets/                  Shared Flutter UI components
  theme/                    JourneySync app theme tokens

supabase/
  migrations/               Database schema migrations
  functions/                Supabase Edge Functions

landing/
  src/                      JourneySync public website
  public/                   Landing assets and beta download artifacts

android/                    Android project and release configuration
ios/                        iOS project configuration
test/                       Flutter tests
scripts/                    Local release automation
```

## Setup

Install Flutter and platform tooling, then install dependencies:

```bash
flutter pub get
```

Run the mobile app:

```bash
flutter run --dart-define-from-file=dart_defines.local.json
```

Run tests:

```bash
flutter test
```

Run analysis:

```bash
flutter analyze
```

Run the landing website locally:

```bash
cd landing
npm install
npm run dev
```

Build the landing website:

```bash
cd landing
npm run build
```

## Environment Configuration

The Flutter app supports these runtime configuration values:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `AUTH_REDIRECT_URL`
- `SUPABASE_AVATAR_BUCKET`

Create a local `dart_defines.local.json` from `dart_defines.local.json.example` and fill in your own project values. Do not commit local environment files or credentials.

The landing website supports these Vite environment values:

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`

Do not place real Supabase URLs, Supabase keys, Auth0 identifiers, passwords, keystore credentials, private tokens, or service-role credentials in this README.

## Android Release

For release signing, create `android/key.properties` locally from `android/key.properties.example` and point it to your local keystore.

Build a release APK:

```bash
flutter build apk --release --dart-define-from-file=dart_defines.local.json
```

For the local release helper:

```powershell
.\scripts\release.ps1 -Version 1.1.1
```

Keep signing files, keystores, and local dart define files outside Git.

## iOS

The iOS project is present under `ios/`. Configure signing, bundle identifiers, provisioning profiles, and distribution through Xcode for the target Apple account.

Location, camera, and photo permission descriptions are configured in `ios/Runner/Info.plist`.

## Security

- Do not commit secrets, service-role keys, client secrets, keystore passwords, private keys, or local environment files.
- Keep `dart_defines.local.json`, `android/key.properties`, keystores, build artifacts, IDE files, and local credentials ignored.
- Use Supabase Row Level Security for user data access.
- Report security issues using [SECURITY.md](./SECURITY.md).

## License

MIT. See [LICENSE](./LICENSE).
