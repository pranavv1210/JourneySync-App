# JourneySync Codebase Walkthrough

This document explains the current JourneySync app as it exists in this repo. A few expectations are different from the code:

- The Flutter app does **not** use Riverpod. State is mostly `StatefulWidget` state, singleton `ChangeNotifier` coordinators, `StreamController`s, and service classes.
- The active authentication flow is **Google OAuth through Supabase**, not phone OTP. The login screen has a "Continue with Phone" button, but it only shows a toast saying phone verification can be added later.
- Supabase integration is direct from the Flutter client using the anon key plus the logged-in Supabase Auth session. There is no separate backend API server for the app.

## 1. High-Level Architecture

JourneySync is a Flutter client backed by Supabase. The pattern is closest to:

```text
Stateful Flutter screens
  -> feature/service classes
  -> Supabase Flutter client
  -> Postgres tables + Supabase Realtime + Supabase Auth + Storage
```

It is **not MVC or MVVM in a strict sense**. Screens often own UI state and call services directly. A few longer-lived flows are centralized in singleton coordinators:

- `ActiveRideCoordinator`: current active ride snapshot, ride restore, members, route, live locations.
- `RealtimeCoordinator`: Supabase Realtime channels for radar, members, routes, alerts, presence.
- `NotificationCoordinator`: in-app persisted notifications.

### Layer Diagram

```text
Flutter widgets/screens
  login_screen.dart
  sign_in_screen.dart
  create_ride_screen.dart
  ride_lobby_screen.dart
  ride_mode_screen.dart
  nearby_rides_screen.dart
  home_screen.dart
        |
        | setState(), listeners, StreamSubscription, singleton ChangeNotifier
        v
Coordinators / screen state
  ActiveRideCoordinator
  RealtimeCoordinator
  NotificationCoordinator
        |
        | method calls, callbacks, streams
        v
Services
  AuthService
  SupabaseService
  RideService
  RideFlowService
  LiveTrackingService
  NotificationService
  WeatherService
        |
        | Supabase.instance.client
        v
Supabase
  Auth: Google OAuth sessions
  Postgres: profiles, rides, ride_members, live_locations, ride_routes, ride_alerts, notifications, ride_summaries
  Realtime: rides, ride_members, live_locations, ride_routes, ride_alerts, profiles
  Storage: avatar bucket
```

### Startup Flow

`lib/main.dart` is the entry point:

1. Loads `.env` if present.
2. Initializes Firebase and Crashlytics if available.
3. Initializes Supabase using `.env` values or `AppConfig` defaults.
4. Calls `ActiveRideCoordinator.instance.restore()` so an active ride can survive app restart.
5. Runs `JourneySyncApp`, whose home is `SplashScreen`.

`SplashScreen` waits for initialization and a 2.8 second intro animation. Then it checks `SharedPreferences.isLoggedIn`:

- `true` -> `HomeScreen`
- `false` -> `LoginScreen`
- initialization error -> `SetupErrorScreen`

### Top-Level Folder Structure

- `lib/`: main Flutter application code.
- `lib/screens/`: full app screens and feature flows. These are large and often contain both UI and feature orchestration.
- `lib/services/`: Supabase, auth, ride, live tracking, weather, navigation, notification, analytics, and config services.
- `lib/coordinators/`: singleton `ChangeNotifier` objects for cross-screen live state.
- `lib/models/`: typed data models such as `RideRecord`, `RideMember`, `RiderLocation`, `RideRoute`, notifications, and presence info.
- `lib/widgets/`: reusable UI widgets, both generic app components and ride-specific widgets.
- `lib/theme/`: colors, typography, spacing, shadows, app theme.
- `lib/utils/`: helper utilities such as route parsing and logging.
- `supabase/migrations/`: SQL schema migrations for app tables, RLS policies, realtime publication, and beta landing-page tables.
- `supabase/functions/`: Supabase Edge Function code, currently beta welcome email.
- `landing/`: separate React/Vite landing site, not the Flutter app.
- `assets/`: app images, logo, SVG, and legal text.
- `android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/`: Flutter platform projects.
- `test/`: current Flutter tests.
- `docs/`: project documentation.

## 2. State Management

There is no Riverpod provider tree. The main patterns are:

- **Screen-local state**: `StatefulWidget` fields plus `setState`. Example: form text, loading flags, selected bike, pending join requests, nearby ride list.
- **Singleton global-ish state**: `ActiveRideCoordinator.instance`, `RealtimeCoordinator.instance`, and `NotificationCoordinator.instance`.
- **Streams**: `LiveTrackingService.watchRideLocations()` returns a stream of rider locations backed by Supabase Realtime.
- **Local persistence**: `SharedPreferences` stores login flags, user profile basics, active ride id, garage state, and offline live-location queues. `FlutterSecureStorage` stores auth token copies.

### One Real State Object End-to-End: ActiveRideCoordinator

`ActiveRideCoordinator` lives in `lib/coordinators/active_ride_coordinator.dart`.

It stores an `ActiveRideSnapshot`:

- ride id
- ride status
- host id
- current profile id
- whether current user is host
- route
- members
- live rider locations
- last SOS alert

The important entry point is `attachRide()`:

1. `RideModeScreen._initRideMode()` calls `ActiveRideCoordinator.instance.attachRide(...)`.
2. `attachRide()` loads the ride row from `SupabaseService.fetchRideById()`.
3. It fetches members through `RideService.fetchRideMembers()`.
4. It fetches route data through `RideService.fetchRideRoute()`.
5. It writes a new `ActiveRideSnapshot` and calls `notifyListeners()`.
6. It stores `activeRideId` and `activeRideStatus` in `SharedPreferences`.
7. It subscribes to `LiveTrackingService.watchRideLocations(rideId)`.
8. It starts ride-session realtime listeners via `RealtimeCoordinator.startRideSession(...)`.
9. If `startTracking` is true, it starts outbound GPS syncing through `LiveTrackingService.startSyncing(...)`.

What causes it to rebuild/listen:

- `LiveTrackingService` emits new location lists when Supabase Realtime receives a `live_locations` change.
- `RealtimeCoordinator` calls callbacks when `ride_members`, `ride_routes`, or `ride_alerts` change.
- Manual calls such as `refreshRoute()`, `markCompleted()`, and `clear()` update the snapshot.

Which widgets consume it:

- `RideModeScreen` registers `ActiveRideCoordinator.instance.addListener(_onActiveRideSnapshotChanged)`.
- In that listener, it copies snapshot fields into screen-local state: members, route, rider locations, current alert.
- `RideModeScreen.dispose()` removes the listener, but intentionally does not dispose tracking when merely leaving/minimizing the screen.

### Global vs Screen-Local State

Global-ish state is used for things that must outlive one screen:

- active ride session
- realtime ride/radar subscriptions
- notification state
- live tracking service
- persisted active ride restore

Screen-local state is used for one-screen UI:

- `CreateRideScreen`: ride name, destination query, selected bike, stops, loading flags.
- `RideLobbyScreen`: loaded ride row, crew list, pending requests, weather, local loading.
- `NearbyRidesScreen`: current scan result list, join button state, empty-state timer.
- `SignInScreen`: privacy checkbox and loading state.

The architecture is pragmatic but inconsistent: some screens call `Supabase.instance.client` directly, while others go through `RideService` or `SupabaseService`.

## 3. Authentication Flow

### What Exists: Google OAuth Login

Phone OTP is not implemented in the current app. The "Continue with Phone" button in `LoginScreen` calls `_showPhoneLater()` and displays a toast. The real auth flow is:

1. User opens the app.
2. `SplashScreen` checks `SharedPreferences.isLoggedIn`.
3. If not logged in, the app shows `LoginScreen`.
4. User taps `Continue with Google`, which pushes `SignInScreen`.
5. `SignInScreen` requires the privacy policy checkbox.
6. User taps `Continue with Google`.
7. `SignInScreen._signIn()` calls `AuthService.authenticateWithGoogle()`.
8. `AuthService.authenticateWithGoogle()`:
   - signs out any existing Supabase session,
   - calls `Supabase.instance.client.auth.signInWithOAuth(OAuthProvider.google)`,
   - uses redirect URL `journeysync://login-callback`,
   - waits for `onAuthStateChange` if the session is not immediately available.
9. `AuthService._identityFromSession()` extracts Supabase user id, email/phone metadata, name metadata, access token, and provider token.
10. `SignInScreen._signIn()` calls `AuthService.resolveUser(isNewAccount: false)`.
11. `resolveUser()` looks up a JourneySync profile by Supabase auth user id or identity variants.
12. If no profile exists during sign-in, the user is sent to `CreateAccountScreen`.
13. If a profile exists, `AuthService.saveSession()` writes local session cache.
14. The app navigates to `HomeScreen`.

For account creation, `CreateAccountScreen._createAccount()` follows the same Google OAuth call but passes `isNewAccount: true` plus entered name and bike. `AuthService.resolveUser()` then creates or updates the `profiles` row through `SupabaseService.upsertAuthenticatedUserProfile()`.

### Session Persistence

The app relies on two layers:

- Supabase Flutter persists its own auth session internally.
- `AuthService.saveSession()` stores JourneySync-specific profile data:
  - `SharedPreferences`: `isLoggedIn`, `userId`, `userPhone`, `userEmail`, `userName`, `userBike`, `userAvatarUrl`.
  - `FlutterSecureStorage`: `phoneEmailAccessToken`, `phoneEmailJwtToken`.

On restart:

1. `main.dart` initializes Supabase.
2. `ActiveRideCoordinator.restore()` tries to restore an active ride from `SharedPreferences.activeRideId` and `userId`.
3. `SplashScreen` checks `SharedPreferences.isLoggedIn`.
4. If logged in, it goes directly to `HomeScreen`.

Important shortcut: `SplashScreen` does not validate the Supabase auth session before routing to home. Later screens may fail with "missing session" or RLS errors if `isLoggedIn` is stale.

## 4. Backend / Supabase Integration

### Main App Tables

The intended schema is spread across migrations. The core app tables are:

- `profiles`: one rider profile per Supabase auth user. Stores name, phone/email-ish identity, bike, avatar URL, active ride id, FCM token, garage data from later migrations, and timestamps.
- `rides`: ride/lobby records. Stores host id, title, start/end labels or coordinates, status, start/end timestamps, max riders, visibility, and ride mode.
- `ride_members`: membership and join requests. Stores ride id, member profile id, role, status (`pending`, `approved`, `rejected`), presence-related columns, and creation time.
- `live_locations`: current live location per rider per ride. Stores ride id, profile id, lat/lng, speed, heading, battery/signal, display name, bike name, leader flag, app state, accuracy, queue timestamp, and update time.
- `ride_routes`: one route record per ride. Stores route labels, JSON stops, destination coordinates, route points, host id, and update time.
- `ride_alerts`: SOS and ride alert events. Stores ride id, profile id, user name, type, message in app payloads, coordinates, and creation time.
- `notifications`: persisted app notifications per profile.
- `ride_summaries`: completed ride analytics/summary data.

Other tables:

- `users`: legacy table retained/backfilled by older migrations.
- `ride_messages`: older live ride message table.
- `beta_applications`: landing-site beta signup table.

### Auth, API Keys, and RLS

`main.dart` initializes Supabase with:

- `SUPABASE_URL` from `.env` or `AppConfig.supabaseUrl`
- `SUPABASE_ANON_KEY` from `.env` or `AppConfig.supabaseAnonKey`

The anon key is public by design in Supabase client apps. Security is supposed to come from:

- Supabase Auth user sessions.
- RLS policies in migrations.

RLS is mixed:

- `profiles` is owner-scoped using `auth.uid() = auth_user_id` in the newer compatibility migration.
- `ride_members`, `live_locations`, `ride_routes`, and `ride_alerts` are broadly open to any authenticated user in the foundation migration.
- `notifications` and `ride_summaries` are more owner/member scoped in hardening migrations.

Senior-engineer note: broad `for all to authenticated using (true)` policies are convenient for demos but fragile for production privacy/security.

### Full Feature Flow: Creating a Ride Lobby

Button tap to database:

1. User opens `CreateRideScreen`.
2. User enters ride name and destination, chooses a bike, and taps create.
3. `CreateRideScreen.createRide()` validates ride name, destination, session, and selected bike.
4. It resolves the creator id from `SharedPreferences` or current Supabase profile.
5. It stores the selected bike in `SharedPreferences`.
6. It resolves start location, usually current coordinates/label.
7. It calls `RideService.createRide(...)`.
8. `RideService.createRide()` calls `SupabaseService.createRide(...)`.
9. `SupabaseService.createRide()` inserts into `rides` with `host_id`, title, locations, status, visibility, mode, and max riders where supported.
10. `RideService.createRide()` immediately calls `joinRide(... suppressDuplicate: true)` so the host is also in `ride_members`.
11. `CreateRideScreen.createRide()` saves route data via `RideService.saveRideRoute(...)`, which upserts `ride_routes`.
12. The UI navigates to `RideLobbyScreen`.

Sync to others:

- `RealtimeCoordinator.startRideRadar()` subscribes to `rides` and `ride_members` changes for nearby scanning.
- When a new public active ride appears or ride/member data changes, radar refreshes through `RideService.searchNearbyRides()`.
- Other riders see the ride in `NearbyRidesScreen` if it is public, active/live, not completed/archived, not hosted by them, and within distance if coordinates are parseable.

Important detail: newly created rides default to `scheduled`, so they may not appear in nearby active ride radar until the host starts the ride and `RideService.startRide()` updates status to `active`.

## 5. Real-Time / Live Features

JourneySync uses **Supabase Realtime websockets**, not pure polling. It also does initial snapshot fetches before realtime subscriptions.

### Live Ride Tracking

`LiveTrackingService` owns the live tracking mechanics:

- `watchRideLocations(rideId)`:
  - fetches initial rows from `live_locations`,
  - subscribes to Supabase Realtime channel `live_tracking:$rideId`,
  - listens to all Postgres changes on `live_locations` filtered by `ride_id`,
  - updates an in-memory map by rider id,
  - emits sorted `List<RiderLocation>` through a broadcast stream.

- `startSyncing(...)`:
  - checks location permission,
  - starts Android foreground location service through a `MethodChannel`,
  - starts `Geolocator.getPositionStream()` with high accuracy and `distanceFilter: 3`,
  - stores the latest GPS position,
  - periodically uploads the latest position to `live_locations`.

### Throttling and Transmission

Outbound upload is adaptive:

- Position stream captures every movement of at least about 3 meters.
- Upload timing is controlled by `RideEngineCore.syncIntervalFor(...)`.
- `RideEngineCore.shouldSyncLocation(...)` decides whether movement is worth syncing.
- Emergency mode (`setEmergencySync(true)`) shortens the interval and immediately attempts an upload.
- If upload fails, payloads go into an offline queue in memory and `SharedPreferences`.
- Queue size is capped at 200 entries.
- On reconnect/success, the service flushes queued positions back to Supabase.

There are two GPS streams in ride mode:

- `RideModeScreen._startLocalGpsStream()` for local UI speed/distance/current dot.
- `LiveTrackingService.startSyncing()` for uploads.

That duplication works, but it is battery-expensive and can drift in behavior.

## 6. Key Features

### Ride Lobby

Owned by:

- `lib/screens/create_ride_screen.dart`
- `lib/screens/ride_lobby_screen.dart`
- `lib/services/ride_service.dart`
- `lib/services/supabase_service.dart`
- `lib/models/ride_record.dart`
- `lib/models/ride_route.dart`

User flow:

1. Create ride from `CreateRideScreen`.
2. Land in `RideLobbyScreen`.
3. Lobby loads ride row, crew, pending requests, weather, and access code.
4. Host can copy/share access code, approve/reject requests, add route link, edit briefing/details, and start ride.
5. Starting ride calls `RideService.startRide()`, updates `rides.status = active`, then opens `RideModeScreen`.

What can break it:

- Missing or stale `SharedPreferences.userId`.
- RLS blocking ride/profile/member reads.
- Schema mismatch around legacy columns (`creator_id`, `user_id`, `destination`) vs current columns (`host_id`, `member_id`, `end_location`).
- Join request status columns missing.
- Route link parsing unable to extract coordinates.

### Join Requests

Owned by:

- `NearbyRidesScreen` for sending requests.
- `RideService.requestJoinRide()` and `joinRideByAccessCode()`.
- `SupabaseService.createJoinRequest()`.
- `RideLobbyScreen._fetchPendingJoinRequests()`, `_approveJoinRequest()`, `_rejectJoinRequest()`.

User flow:

1. Rider discovers a ride in `NearbyRidesScreen` or enters an access code.
2. App inserts/upserts a `ride_members` row with `status = pending`.
3. Host lobby fetches pending rows.
4. Host approves by updating `ride_members.status = approved`.
5. Realtime member channel refreshes active ride session membership when in ride mode.

What can break it:

- If `ride_members.status` is unavailable, code falls back to direct join in some paths.
- Lobby pending requests are fetched manually, not through a dedicated repository or provider.
- Access codes are derived from the last 4 alphanumeric chars of ride UUIDs, so collisions are possible.

### SOS

Owned by:

- `RideModeScreen._triggerSOS()`
- `RealtimeCoordinator.triggerSOS()`
- `ride_alerts` table
- `SosAlertScreen` for detailed alert handling/viewing
- `NotificationService` and `NotificationCoordinator`

User flow:

1. Rider taps SOS in ride mode.
2. `RideModeScreen._triggerSOS()` enables emergency sync on the tracking service.
3. It calls `RealtimeCoordinator.triggerSOS(...)`.
4. Coordinator inserts a row into `ride_alerts`.
5. Coordinator persists a local notification record and shows a local notification.
6. Other riders subscribed to `ride:$rideId:alerts` receive the inserted alert.
7. Their UI updates `lastAlert`, marks presence as SOS, and shows a local notification.

What can break it:

- No current GPS position means alert may have no coordinates.
- `ride_alerts` RLS/schema issues.
- Local notification permissions.
- Riders not attached to the ride session will not have the ride alert channel open.

### Ride History

Owned by:

- `RideHistoryScreen`
- `MyRidesScreen`
- `RideService.fetchRecentRides()`
- `SupabaseService.fetchRecentRidesByCreator()`
- `ride_summaries` migration support, though current screen logic mainly uses ride records.

User flow:

1. Screen reads `SharedPreferences.userId`.
2. Service fetches rides hosted by the user plus rides where they are an approved member.
3. Completed/archived status affects what is shown.
4. Ride mode completion calls `RideService.finishRide()` and local analytics completion.

What can break it:

- Missing member rows means participant rides disappear.
- Archive/status columns are handled with fallbacks, so inconsistent database state can make history unreliable.
- Ride summary persistence is not as centralized as live ride state.

### Nearby Ride Alerts / Radar

Owned by:

- `NearbyRidesScreen`
- `MapScreen`
- `RealtimeCoordinator.startRideRadar()`
- `RideService.searchNearbyRides()`
- `NotificationCoordinator` and `NotificationService`

User flow:

1. User opens nearby rides.
2. Screen asks `RealtimeCoordinator` to start radar for current profile.
3. Coordinator resolves current GPS origin if allowed.
4. It fetches nearby public active rides.
5. It subscribes to `rides` and `ride_members` changes.
6. On changes, it debounces and refreshes the radar list.
7. New nearby rides can create persisted and local notifications.

What can break it:

- Location permission denied.
- Ride start locations are plain strings; distance filtering only works if they parse as `lat,lng`.
- Only public active/live rides show in radar.
- Realtime publication must include `rides` and `ride_members`.

## 7. Dependencies and Why They Are There

- `supabase_flutter`: Supabase Auth, database, storage, and realtime client.
- `shared_preferences`: local session flags, profile cache, active ride restore, and offline location queue persistence.
- `flutter_secure_storage`: stores token copies outside normal preferences.
- `flutter_map`: map rendering in ride, nearby, SOS, and route screens.
- `latlong2`: coordinate model used with `flutter_map`.
- `geolocator`: GPS permission, current location, live position streams, distance calculations.
- `http`: external HTTP calls such as destination search/weather.
- `intl`: date/time and display formatting.
- `share_plus`: sharing ride invite/access information.
- `image_picker`: profile/avatar image selection.
- `image_cropper`: avatar image cropping.
- `sentry_flutter`: error monitoring.
- `url_launcher`: opening navigation URLs, phone calls, external links.
- `battery_plus`: battery metadata for live ride HUD/tracking.
- `connectivity_plus`: realtime reconnect/offline awareness.
- `path_provider`: local file/cache path access where needed by platform features.
- `firebase_core`: initializes Firebase.
- `firebase_messaging`: push notification token/messaging support.
- `flutter_local_notifications`: local notifications for SOS, ride events, nearby ride alerts.
- `firebase_crashlytics`: crash reporting.
- `firebase_analytics`: analytics route observer and event tracking.
- `flutter_dotenv`: loads runtime `.env` config.
- `shimmer`: skeleton/loading effects.
- `app_links`: deep link support for auth redirects.
- `flutter_svg`: renders Google logo and SVG assets.

## 8. Weak Points / Tech Debt

- **No single state-management pattern.** The app mixes screen state, singleton coordinators, direct Supabase calls, services, streams, and preferences. This makes ownership hard to reason about.
- **No Riverpod despite app complexity.** Riverpod is not required, but this app has enough cross-screen state that providers would make dependencies, lifetimes, rebuilds, and tests clearer.
- **Screens are too large.** `ride_mode_screen.dart` and `ride_lobby_screen.dart` own UI, orchestration, data parsing, Supabase calls, and error handling in one place.
- **Supabase access is inconsistent.** Some features use `RideService`/`SupabaseService`; others call `Supabase.instance.client` directly from screens.
- **Schema compatibility fallbacks are everywhere.** Fallbacks for missing columns and legacy names helped migration, but they hide real schema drift and make failures harder to diagnose.
- **RLS is too broad on ride tables.** Authenticated users can do too much on ride/member/location/route/alert tables. This is risky for privacy and abuse.
- **Session routing trusts `SharedPreferences.isLoggedIn`.** The splash screen can send users home even if the Supabase auth session is expired or gone.
- **Location tracking is duplicated.** `RideModeScreen` and `LiveTrackingService` both run GPS streams.
- **Access code design can collide.** Codes derived from UUID tails are convenient but not guaranteed unique.
- **Realtime lifecycle can double-subscribe.** `RideModeScreen` starts tracking directly and then attaches the active ride coordinator, which also owns tracking logic depending on flags. The code avoids one duplicate with `startTracking: false`, but the boundary is fragile.
- **Security-sensitive keys live in app config.** The Supabase anon key is okay to ship, but hardcoding production config makes environment mistakes easier.
- **Tests are thin relative to risk.** The highest-risk flows are auth/session restore, RLS/schema compatibility, realtime subscriptions, and tracking throttling.

## 9. If You Wanted to Add a New Feature

Use this order for a feature comparable to ride lobby, SOS, or nearby alerts.

1. Define the data shape.
   - Add or update a model in `lib/models/` if the feature has a real domain object.
   - Add a Supabase migration under `supabase/migrations/` for any new table/columns/indexes/RLS.

2. Add service methods.
   - Put raw Supabase reads/writes in `SupabaseService` unless the feature already has a dedicated service.
   - Put domain behavior in a higher-level service like `RideService`.
   - Avoid calling Supabase directly from the screen for new work.

3. Decide state ownership.
   - Use screen-local `setState` for short-lived form/loading/UI state.
   - Use a coordinator only if the state must survive navigation, be shared across screens, or listen to realtime.
   - If it is realtime, copy the `RealtimeCoordinator` pattern: initial fetch first, then channel subscription, then callback/listener updates.

4. Build the screen flow.
   - Add UI in `lib/screens/`.
   - Keep validation in the screen, but keep database logic in services.
   - Navigate through `app_navigation.dart` helpers to match the rest of the app.

5. Wire realtime if needed.
   - Add the table to Supabase Realtime publication in a migration.
   - Subscribe in `RealtimeCoordinator` or a dedicated service.
   - Update a single source of truth and notify listeners.

6. Persist local recovery state only if needed.
   - Use `SharedPreferences` for non-secret restore flags.
   - Use `FlutterSecureStorage` for sensitive tokens/secrets.
   - Keep keys named and scoped, like `activeRideId` or `liveTrackingOfflineQueue:$rideId:$userId`.

7. Add failure handling.
   - Handle RLS errors, missing session, location permission, offline state, and schema assumptions explicitly.
   - Avoid adding more silent schema fallbacks unless you are actively supporting an old production database.

8. Add tests around the riskiest part.
   - For services, inject fake `SupabaseService` or fake clients where possible.
   - For pure logic, test models/parsers/throttling without Flutter.
   - For screens, add rendering tests only after logic is isolated enough to avoid brittle UI-only tests.

For a ride-lobby-like feature, touch files in this rough order:

```text
supabase/migrations/<date>_<feature>.sql
lib/models/<feature_model>.dart
lib/services/supabase_service.dart
lib/services/ride_service.dart or lib/services/<feature_service>.dart
lib/coordinators/realtime_coordinator.dart if realtime/shared
lib/screens/<feature_screen>.dart
lib/screens/home_screen.dart or relevant navigation entry point
test/<feature>_test.dart
```

For an SOS-like realtime event feature:

```text
database table or new event type
RealtimeCoordinator method to insert/listen
NotificationCoordinator persistence if user-visible
RideModeScreen button/action
target screen or overlay to display incoming event
RLS policy so only intended riders can send/read it
```

The most important architectural improvement before adding many new features would be to standardize state ownership. Either introduce Riverpod intentionally, or keep the current coordinator/service pattern but make it consistent: screens should consume services/coordinators, services should own Supabase, and direct database calls from screens should stop.
