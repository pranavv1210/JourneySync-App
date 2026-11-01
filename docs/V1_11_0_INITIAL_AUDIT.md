# JourneySync v1.11.0 initial audit

Date: 2026-11-01

Baseline confirmed: clean `main` at `838d89a`, version `1.10.0+25`.

| ID | Severity | Finding | Reproduction/evidence | Resolution/test |
| --- | --- | --- | --- | --- |
| V111-001 | P0 | GPS accuracy existed in the schema but outbound tracking did not persist it, so group separation could trust a poor fix. | Inspect live-location payloads and `RiderLocation`; `accuracy` was absent. | Persist/parse accuracy, classify GPS quality, suppress separation alerts when rider or leader accuracy exceeds 100 m. Unit regression added. |
| V111-002 | P1 | Notification alert details read legacy columns from `rides`, silently swallowed errors, and cancelled by mutating `rides.alert_status`. | Open a Get Help notification and inspect `sos_alert_screen.dart`. | Read the notification payload or latest authorised `ride_alerts` record, log failures, and cancel through the shared realtime lifecycle. |
| V111-003 | P0 | Landing safety mockup still displayed “Crash detected” and an automatic countdown despite that feature not existing. | Safety section source and rendered page. | Replaced with the confirmed four-category Get Help experience and 112 wording. |
| V111-004 | P1 | 320 px landing layout expanded to a grid child’s minimum width, clipping headings, CTAs, and navigation. | Captured 320 px screenshot. | Corrected the mobile container calculation, constrained grid children, stacked CTAs, and added automated overflow QA. |
| V111-005 | P2 | Eight raw `<img>` lint warnings remained. | `npm run lint`. | Migrated local assets to `next/image`; retained one justified runtime QR image suppression. Lint now has zero warnings. |
| V111-006 | P0/external | Production Supabase is not linked to this workspace. | Authenticated CLI sees one project, but linked migration inspection returns `LegacyProjectNotLinkedError`. | Exact production verification checklist recorded; status remains NOT VERIFIED. |
| V111-007 | P0/external | No physical Android devices or separate staging accounts are attached. | Environment inventory. | Automated logic tests and test matrices provided; physical/multi-account results remain NOT VERIFIED. |
| V111-008 | P1 | A developer `DEBUG` environment variable could make `gradlew.bat` echo base64-encoded Dart defines into local release logs. | Prior Windows release output included the Gradle command line. | Release automation now clears `DEBUG` only for the signed build and restores it afterward. |

Previously fixed and preserved: category-aware Get Help, direct 112 dialler,
alert acknowledgement/cancellation, bounded offline queue, active-session
recovery, hardened RLS migrations, signed release automation, and unsupported
crash-detection marketing removal from the text data source.
