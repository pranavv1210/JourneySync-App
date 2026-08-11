-- Align app_feedback RLS with the current profiles.auth_user_id model.

drop policy if exists app_feedback_insert_own on public.app_feedback;
drop policy if exists app_feedback_select_own on public.app_feedback;

create policy app_feedback_insert_own
  on public.app_feedback
  for insert
  to authenticated
  with check (
    user_id = auth.uid()
    or exists (
      select 1
      from public.profiles p
      where p.id = app_feedback.user_id
        and p.auth_user_id = auth.uid()
    )
  );

create policy app_feedback_select_own
  on public.app_feedback
  for select
  to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1
      from public.profiles p
      where p.id = app_feedback.user_id
        and p.auth_user_id = auth.uid()
    )
  );
