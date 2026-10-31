# JourneySync comprehensive audit

Date: 2026-10-31

## Scope

Reviewed Flutter screens, services, coordinators, models, Android manifests and
services, Supabase migrations and regression fixtures, landing source, release
automation, and GitHub workflows. Source review is complete; real-device,
multi-account staging, and privileged production database checks are not
available in this workspace and are explicitly not treated as passed.

## Findings

| ID | Severity | Area / evidence | Finding and impact | Correction / verification |
| --- | --- | --- | --- | --- |
| JS-001 | P1 | `lib/screens/ride_mode_screen.dart` | Emergency entry used a generic SOS prompt, so riders could not state whether they needed medical, breakdown, separation, or general help. | Added Get Help category selection, explicit confirmation, persistent category messaging, and 112 guidance. Unit and Flutter tests cover category compatibility. |
| JS-002 | P1 | `landing/src/data/site-content.ts` | Landing copy advertised phone-sensor crash detection although no reliable automatic crash detector exists. This could create unsafe expectations. | Removed the claim and aligned safety copy with implemented Get Help behavior. Landing lint/build verify source integrity. |
| JS-003 | P1 | Production Supabase catalog | Repository contains hardened RLS migrations, but their production application and actual catalog grants are not privileged-verifiable here. | Keep controlled-beta status until the runbook in the security audit is executed against production. |
| JS-004 | P2 | `lib/screens/sos_alert_screen.dart` | A legacy alert-details screen still uses old SOS and “Rider Down” language and contains best-effort exception handling. | Existing active Ride Mode uses the hardened lifecycle; migrate or retire this notification-only compatibility screen in a follow-up. |
| JS-005 | P2 | Integration coverage | Core logic has widget/unit/security regression tests, but there is no automated real-device two-rider GPS/background suite. | Execute the test matrix in `JOURNEYSYNC_TEST_REPORT.md` on representative Android devices before broad rollout. |
| JS-006 | P3 | Source comments | Some historical source comments contain mojibake box-drawing characters. | Presentation-only; no user-facing runtime effect. Clean mechanically in a dedicated patch to avoid noisy functional diffs. |

## Verified architecture strengths

- Tracking has bounded persistent offline queuing, adaptive updates, reconnect,
  duplicate suppression, and teardown behavior.
- Group intelligence models stale/offline/stopped/separated states instead of
  treating every missing update as “lost.”
- Active ride recovery restores only live/active, non-archived rides.
- SOS/help lifecycle supports realtime delivery, host/group acknowledgement,
  cancellation, notification bookkeeping, and direct emergency calling.
- Security migrations default-deny new Data API objects and CI runs attacker
  policy regression tests.
- Release automation synchronizes versions, builds the signed sideload flavor,
  verifies signature/metadata/hash, publishes the APK, pushes, watches CI, and
  checks deployment.

## Remaining acceptance gaps

Production RLS state, actual emergency delivery with multiple accounts,
background behavior across Android OEMs, notification delivery, and every
responsive width require external environments or physical devices. They are
NOT VERIFIED, not passes.
