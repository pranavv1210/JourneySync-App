# JourneySync production RLS audit — 2026-10-10

## Scope and evidence

The audit covered all 30 repository migrations, `profile_rls_policies.sql`,
Flutter Supabase queries/RPCs/realtime subscriptions, storage policies, the
Edge Function, and GitHub workflows. Repository findings are confirmed from
source. Production findings are limited to anonymous, read-only PostgREST
probes using the publishable key: JourneySync is not linked to the locally
authenticated Supabase CLI account, so `pg_policies`, grants, function owners,
and applied migration history remain pending privileged read-only inspection.

The production probe returned zero rows to anonymous callers for canonical
profiles, memberships, GPS, routes, alerts, and device sessions. It returned
all nine `public` rides, including one completed ride. A follow-up legacy probe
confirmed that `users` exposes five rows and `participants` exposes thirteen
rows anonymously. Historical `users` contains live GPS fields. No sensitive row
contents were recorded.

## Root causes

1. Multiple migrations created permissive `FOR ALL TO authenticated
   USING (true) WITH CHECK (true)` policies. PostgreSQL ORs permissive policies,
   so later narrow policies did not neutralize every earlier grant.
2. Early chat policies had no role restriction and used `USING (true)` /
   `WITH CHECK (true)`.
3. `profile_is_ride_participant_text(ride, profile)` trusted the supplied
   profile rather than binding it to `auth.uid()`. The security-definer SOS RPC
   called that helper, enabling authenticated participant impersonation.
4. Private access codes were validated only in Flutter after enumerating up to
   250 ride rows. Direct PostgREST calls could skip that UI check.
5. Client-side host checks were treated as authorization for ride and
   membership mutations even though the database policies allowed all signed-in
   users.
6. Public ride discovery was not consistently restricted to joinable lifecycle
   states.

## Authorization matrix

| Resource | Repository policy evidence | Required access | Severity / vulnerability | Repair | Functional dependencies |
|---|---|---|---|---|---|
| `profiles` | Owner policies were later overlapped by `profiles_authenticated_all` | Self full access; ride peers/public hosts get summary only; admin read | Critical: any authenticated user could enumerate private profile fields | Self/peer/admin RLS plus constrained `profile_summaries` view | Login, profile, garage, avatars, lobby, radar |
| Legacy `users` | Created before canonical profiles; production anonymously exposes 5 rows | Self/admin only; current app does not query it | Critical: confirmed anonymous legacy profile/GPS exposure | Enable RLS, remove accumulated policies, revoke anon, self/admin policies | Legacy compatibility only |
| Legacy `participants` | Legacy membership source; production anonymously exposes 13 rows | Self, host, or approved ride participant | Critical: confirmed anonymous membership exposure | Enable RLS, revoke anon, scoped select only | Legacy compatibility only |
| `rides` | `rides_authenticated_all`; production anon exposes 9 public rows including a completed ride | Public discovery only for scheduled/planned/active; participants retain history; host writes | High: cross-host mutation and completed discovery | Lifecycle-scoped public select; participant select; host-only write/delete | Discovery, create/edit/start/end/resume |
| `ride_members` | Several `*_all` policies survive migration accumulation | Own row, approved roster, host pending requests; server-validated join | Critical: enumerate, self-approve, role/identity manipulation | Replace all policies; immutable identity trigger; join RPC; host status-only updates | Join, late join, approval, roster, reconnect |
| `live_locations` | `live_locations_all` and `authenticated_all` | Approved ride participants read; rider writes own marker | Critical: cross-ride GPS exposure and spoofing | Participant select; identity-bound insert/update; host/self delete | Live map, reconnect, stale markers |
| `ride_routes` | `ride_routes_all` and `authenticated_all` | Participants read; host writes | High: private route disclosure and cross-host modification | Participant select; host-only CRUD | Destination, pit stops, route sync |
| `ride_alerts` | Broad policies were partly replaced, but compatibility helper trusted supplied profile | Participants read; own SOS/safe; host lifecycle actions | Critical: false SOS impersonation and unrelated alert access | Auth-bound helpers, scoped policies, hardened SOS RPC | SOS, acknowledgement, realtime delivery |
| `ride_messages` | `select_all` and `insert_all` without role restriction | Approved participants read; sender inserts/deletes own; host moderation | Critical if table is deployed: public/API chat exposure and injection | Participant/sender/host policies | Ride chat |
| `notifications` | Owner policies overlapped by `notifications_authenticated_all` | Owner read/update/delete; constrained ride participant delivery | High: cross-user notification access | Owner policies and ride-scoped insert | Notification center, SOS bookkeeping |
| `ride_summaries` | Narrow policies overlapped by `ride_summaries_authenticated_all` | Participants read; host writes | High: private history exposure/modification | Participant read; host CRUD | Ride history and summaries |
| `user_device_sessions` | Owner/admin policies; auth-bound register RPC | Owner/admin only | No confirmed repository bypass | Retained; production catalog verification required | Single-device session enforcement |
| Avatar storage | Public read; owner-path insert/update/delete | Public avatars intentionally readable; owner writes | Low/intentional public asset | Retained; verify bucket is avatar-only | Profiles and lobby avatars |
| Account deletion | Owner/admin policies and admin security-definer RPC | Owner request; app-metadata admin review | No confirmed bypass; verify owner/grants/search path | Existing checks retained | Privacy/deletion workflow |
| Beta applications | Anonymous insert with `WITH CHECK(true)`; admin read/manage | Public signup submission only | Medium abuse/spam risk, not rider-data disclosure | Out of incident scope; rate-limit/abuse review recommended | Landing beta signup |

## Implemented repair

### Production migration-ledger normalization

Five migrations that production recorded with legacy date-only identifiers now
use unique 14-digit identifiers in the repository. Before the next production
schema deployment, an authorized operator must run
`supabase/operations/normalize_legacy_migration_versions.sql` in the JourneySync
project SQL editor. The script is deliberately not an automatic migration: it
checks for exactly five old identifiers and no normalized identifiers, updates
only `supabase_migrations.schema_migrations.version`, verifies exactly five
rows, and aborts the whole transaction if any precondition or postcondition
fails.

Recovery, if the deployment has not applied any later migration, is the inverse
mapping inside a transaction:

| Normalized version | Legacy version |
| --- | --- |
| `20260306000000` | `20260306` |
| `20260326000000` | `20260326` |
| `20260415000000` | `20260415` |
| `20260527000000` | `20260527` |
| `20260621000000` | `20260621` |

Do not reverse the mapping after later migrations have been deployed. Take a
fresh ledger snapshot and investigate instead.

The RLS regression workflow now rejects migration filenames that do not use a
unique 14-digit timestamp. This prevents another date-only or duplicate-version
file from reaching `main` and recreating the deployment-ledger mismatch.

- `20261010000000_production_rls_security_hardening.sql` performs strict schema
  precondition checks, drops every accumulated policy on protected resources,
  installs explicit per-command policies, restricts grants, and replaces unsafe
  helpers/RPCs.
- `request_ride_join` derives identity from the JWT, validates ride lifecycle,
  private access code, capacity, and duplicate state under a row lock.
- `join_ride_by_access_code` resolves private codes server-side without exposing
  the ride catalogue.
- Membership identity/role fields are immutable to client updates.
- The SOS fallback RPC now binds the alert profile to the authenticated profile;
  only a host can create a group broadcast.
- Flutter private-code joining uses the server RPC instead of client catalogue
  enumeration.

## Deployment and recovery

1. Take a Supabase database backup or point-in-time recovery checkpoint. Export
   the current policy/function/grant catalog with the verification script.
2. Apply all pending migrations to an isolated/staging clone first.
3. Run `supabase/tests/rls_security_regression.sql` and Flutter regression tests.
4. Test two real staging riders: public join, private code join, host approval,
   GPS/realtime, reconnect, chat, SOS and acknowledgement.
5. Apply the migration to production through the established Supabase migration
   process. Do not paste only selected statements.
6. Immediately run `production_rls_verification.sql` and anonymous/authenticated
   negative API probes. Revoke a test member while subscribed and verify no new
   protected events arrive.
7. Monitor PostgREST 401/403/42501 errors, Realtime channel failures, and SOS
   delivery before publishing the matching client APK.

The migration is transactional. A failure before `commit` rolls back all policy
changes. After commit, recovery should restore the pre-change database snapshot
or apply a separately reviewed forward recovery migration generated from the
captured catalog; do not re-enable blanket historical policies.

## Production status

- Confirmed from production: canonical sensitive-table reads returned zero rows,
  but legacy `users` (5 rows) and `participants` (13 rows) were anonymously
  enumerable; public ride discovery also included a completed ride.
- Confirmed from repository: critical authenticated cross-ride policies and SOS
  identity bypass exist in migration history.
- Pending: actual `pg_policies`, function owner/ACL, grants, publication, applied
  migration list, and authenticated attacker tests on JourneySync production.
- The migration has **not** been applied to production because no authorized
  JourneySync project/database connection is available in this workspace.
