alter table public.beta_applications
add column if not exists platform text not null default 'android';

update public.beta_applications
set platform = lower(platform)
where platform is not null;

update public.beta_applications
set platform = 'android'
where platform not in ('android', 'ios');

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'beta_applications_platform_check'
      and conrelid = 'public.beta_applications'::regclass
  ) then
    alter table public.beta_applications
    add constraint beta_applications_platform_check
    check (platform in ('android', 'ios'));
  end if;
end $$;

create index if not exists beta_applications_platform_created_at_idx
on public.beta_applications (platform, created_at desc);
