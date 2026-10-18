# Supabase Data API authorization contract

JourneySync adopted default-deny privileges for future `public` schema objects
before Supabase's October 30, 2026 rollout. Existing objects are intentionally
unchanged; the production RLS hardening migration remains their authority.

For every new table migration:

1. Create the table.
2. Enable row-level security.
3. Revoke access from `public` and `anon`.
4. Grant only the commands required by `authenticated` or another intended
   database role.
5. Add command-specific RLS policies with both `using` and `with check` where
   appropriate.
6. Add positive and attacker-negative regression tests.

```sql
create table public.example (...);
alter table public.example enable row level security;
revoke all on table public.example from public, anon, authenticated;
grant select, insert on table public.example to authenticated;
```

For every new RPC, revoke PostgreSQL's default public execution and grant only
the intended caller:

```sql
create function public.example_rpc() returns void ...;
revoke all on function public.example_rpc() from public, anon, authenticated;
grant execute on function public.example_rpc() to authenticated;
```

Never use a blanket grant over every table as remediation. PostgreSQL grants
determine whether a role can reach an object at all; RLS separately determines
which rows an allowed role can access. Both layers are required.
