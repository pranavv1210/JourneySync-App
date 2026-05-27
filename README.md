<div align="center">

<img src="assets/logo.png" alt="JourneySync Logo" width="100" />

# JourneySync

### *The Premium Real-Time Group Ride Coordination & Safety App*

[![Flutter CI/CD Quality Pipeline](https://github.com/pranavv1210/JourneySync-App/actions/workflows/flutter-ci.yml/badge.svg)](https://github.com/pranavv1210/JourneySync-App/actions/workflows/flutter-ci.yml)
[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)
[![Auth0](https://img.shields.io/badge/Auth0-111827?style=for-the-badge&logo=auth0&logoColor=white)](https://auth0.com)

</div>

---

## 🏍️ Overview

**JourneySync** is a premium, real-time group motorcycle ride coordination and safety application designed to deliver seamless synchronization on the open road. Engineered for adventure, JourneySync integrates live rider tracking, real-time location streaming, offline data queueing, automated route sync, and an instantaneous emergency SOS system into an exquisite, smooth, and highly responsive Flutter application.

---

## ✨ Features

- **🏍️ Premium Ride Mode**: Immersive full-screen active riding dashboard with smooth map visualization and a beautiful HUD.
- **📍 Real-Time Live Rider Tracking**: High-performance rider location sync using Supabase Realtime, with smooth marker transition animations (`SmoothMarker`).
- **🛡️ SOS Emergency System**: Instant safety trigger mechanism with visual overlays, battery percent tracking, and haptic warnings.
- **👑 Active Leader Mode**: Autonomous map centering and navigation focus following the designated group ride leader.
- **🔄 Auto Route Sync**: Immediate synchronization of the ride path, destination points, and stops directly across all participants' screens.
- **🔌 Offline Resiliency**: Robust offline location queuing system that caches GPS updates when signal is weak and automatically flushes them on reconnection.
- **🔐 Phone.Email OTP Auth**: Secure, high-speed one-tap Auth0 passwordless authentication for returning riders.

---

## 🛠️ Technology Stack

- **Frontend Core**: [Flutter](https://flutter.dev) (Dart SDK `^3.7.2` stable)
- **Backend Architecture**: [Supabase](https://supabase.com) (Realtime subscriptions, PostgreSQL DB, and Cloud Storage)
- **Identity & Authentication**: [Auth0](https://auth0.com) passwordless phone auth
- **Maps Engine**: [Flutter Map](https://github.com/fleaflet/flutter_map) + [Leaflet](https://leafletjs.com/) with open-source OpenStreetMap layers
- **External Navigation Linkage**: [Google Maps Deep-Link Integration](https://developers.google.com/maps)
- **Telemetry & Location API**: [Geolocator](https://pub.dev/packages/geolocator)
- **Crash Tracking & Logging**: [Sentry SDK](https://sentry.io/)

---

## 📦 Directory Structure

```text
lib/
├── legal/                   # Terms of Service & Privacy Policy resources
├── models/                  # Strong-typed application models (Rider, Route, LiveLocation)
├── screens/                 # Premium views (Ride Mode, SOS, Login, Lobby, Summary)
├── services/                # Backend layers (Supabase, Auth0, Geolocator, Weather)
├── utils/                   # Shared helpers & navigation transition structures
├── widgets/                 # Elegant custom visual widgets (SmoothMarker, AppToast)
└── main.dart                # Application entry point & service bootstrap
```

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK `^3.7.2` or later
- Android Studio / Xcode configured for Android/iOS builds

### 1. Repository Setup & Dependencies
Clone the repository and install all packages:
```bash
git clone https://github.com/pranavv1210/JourneySync-App.git
cd JourneySync-App
flutter pub get
```

### 2. Configure Environment Properties
Create `dart_defines.local.json` in the root of your project using the template `dart_defines.local.json.example`:
```json
{
  "SUPABASE_URL": "https://YOUR_SUPABASE_PROJECT.supabase.co",
  "SUPABASE_ANON_KEY": "YOUR_ANON_KEY",
  "AUTH0_DOMAIN": "YOUR_TENANT.auth0.com",
  "AUTH0_CLIENT_ID": "YOUR_CLIENT_ID",
  "AUTH0_SCHEME": "journeysync",
  "SUPABASE_AVATAR_BUCKET": "avatars"
}
```

### 3. Run in Debug Mode
To run JourneySync locally with injected runtime defines:
```bash
flutter run --dart-define-from-file=dart_defines.local.json
```

### 4. Build Android Release APK
To compile a production debug/release build:
```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release --dart-define-from-file=dart_defines.local.json
```

---

## 🧪 CI/CD Quality Checks

All commits and pull requests submitted to the protected `main` and `dev` branches are automatically validated using a professional GitHub Actions workflow.

To verify your changes locally before pushing:
```bash
# Verify formatting
dart format --set-exit-if-changed .

# Static analysis
flutter analyze

# Run unit & widget tests
flutter test
```

---

## 🗺️ Roadmap & Future Vision

- [ ] **Dynamic Offline Maps**: Pre-caching OSM map tiles along the planned route for offline exploration.
- [ ] **Helmet Intercom Sync**: Live audio link integrations with Bluetooth headsets.
- [ ] **Telemetry Overlay**: Real-time lean angle, altitude, and acceleration tracking.
- [ ] **iOS Live Activities**: Premium iOS Lock Screen live distance widget.

---

## 🤝 Contribution Guidelines

We follow standard engineering workflows. To propose a change:
1. Review the [Release Process Guide](./RELEASE_PROCESS.md) for branch strategy.
2. Format your commit messages using the **Conventional Commits** specification.
3. Submit a Pull Request targeting the `dev` branch for review.
