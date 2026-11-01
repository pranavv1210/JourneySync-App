# Supabase security verification

Date: 2026-11-01

## Repository review

- Reviewed protected tables, accumulated migrations, security-definer helpers,
  explicit grants, default privileges, realtime publication setup, and the SQL
  attacker fixtures.
- `scripts/check-supabase-migration-grants.ps1`: **PASS** (one migration in the
  enforced range validated).
- The existing CI security workflow tests anonymous, cross-user, leader/member,
  mixed-identity, admin, function-grant, and default-privilege regressions in an
  isolated PostgreSQL service.
- No new table, function, grant, or migration is introduced by v1.11.0.

## Production status

**NOT VERIFIED.** The CLI is authenticated to one project but this repository is
not linked; `supabase migration list --linked` returned
`LegacyProjectNotLinkedError`. No production mutation was attempted.

An authorised owner must link the correct project read-only, compare remote and
local migration ledgers, run `supabase/production_rls_verification.sql`, inspect
`pg_policies`, grants, function owner/search paths/ACLs, storage policies and
realtime publication membership, then execute Account A/B/C/D negative tests.
Former-member subscriptions must be checked after revocation and completion.

Until that evidence exists, RLS, grants, functions, realtime authorisation,
account isolation, location privacy and Get Help privacy are NOT VERIFIED in
production, regardless of repository test results.
