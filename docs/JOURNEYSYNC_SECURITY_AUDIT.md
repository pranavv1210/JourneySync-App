# JourneySync security and privacy audit

Date: 2026-10-31

## Result

Repository controls are strong, but production is not declared verified. The
detailed policy analysis and historical vulnerabilities are recorded in
`SECURITY_RLS_AUDIT_2026-10-10.md`.

## Repository evidence

- Protected tables use RLS migrations and explicit grants.
- The 2026-10-10 hardening migration removes accumulated permissive policies,
  binds identity to JWT claims, restricts membership/location/alert access, and
  hardens security-definer functions.
- The 2026-10-18 migration establishes default-deny privileges for future Data
  API tables, sequences, and functions.
- `scripts/check-supabase-migration-grants.ps1` and the `security-rls` workflow
  enforce migration grant rules and attacker-policy regressions.
- Client configuration contains publishable configuration only; local defines,
  keystores, and signing properties are ignored and must not be committed.
- Android backup is disabled and services/components declare explicit export
  behavior.

## Required production verification

1. Confirm applied migration versions through privileged read-only catalog
   access.
2. Run `supabase/production_rls_verification.sql`.
3. Execute unauthenticated, User A/User B, host, participant, non-member, and
   former-member negative tests.
4. Revoke a subscribed member and verify protected realtime events stop.
5. Verify legacy `users` and `participants` are no longer anonymously readable.
6. Confirm function owners, `search_path`, EXECUTE grants, storage policies,
   and publication membership.

Until those checks pass, production security is **NOT VERIFIED** and the app is
appropriate only for controlled beta use.
