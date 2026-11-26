-- Move member mutations to SECURITY INVOKER and enforce them with RLS.
-- This keeps the privilege boundary in PostgreSQL policies rather than elevated RPC code.

create or replace function private.is_agency_owner(target_agency uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.agency_members m
    where m.agency_id = target_agency
      and m.user_id = (select auth.uid())
      and m.role = 'owner'
  );
$$;
revoke all on function private.is_agency_owner(uuid) from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.is_agency_owner(uuid) to authenticated;

drop policy if exists "Agency owners can update non-owner member roles" on public.agency_members;
create policy "Agency owners can update non-owner member roles"
on public.agency_members for update to authenticated
using (private.is_agency_owner(agency_id) and role <> 'owner' and user_id <> (select auth.uid()))
with check (private.is_agency_owner(agency_id) and role in ('admin', 'agent') and user_id <> (select auth.uid()));

drop policy if exists "Agency admins can remove eligible members" on public.agency_members;
create policy "Agency admins can remove eligible members"
on public.agency_members for delete to authenticated
using (
  private.is_agency_admin(agency_id)
  and role <> 'owner'
  and user_id <> (select auth.uid())
  and (private.is_agency_owner(agency_id) or role = 'agent')
);

grant update (role) on public.agency_members to authenticated;
grant delete on public.agency_members to authenticated;

create or replace function public.update_agency_member_role(target_agency uuid, target_user uuid, new_role text)
returns void language plpgsql security invoker set search_path = ''
as $$
declare target_role text; affected_rows integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if target_user = auth.uid() then raise exception 'You cannot change your own agency role'; end if;
  if new_role not in ('admin', 'agent') then raise exception 'Unsupported agency role'; end if;
  select m.role into target_role from public.agency_members m
  where m.agency_id = target_agency and m.user_id = target_user;
  if target_role is null then raise exception 'Agency member not found'; end if;
  if target_role = 'owner' then raise exception 'The agency owner role cannot be changed here'; end if;
  update public.agency_members set role = new_role
  where agency_id = target_agency and user_id = target_user and user_id <> (select auth.uid());
  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then raise exception 'You are not allowed to change this member role'; end if;
end;
$$;

create or replace function public.remove_agency_member(target_agency uuid, target_user uuid)
returns void language plpgsql security invoker set search_path = ''
as $$
declare target_role text; affected_rows integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if target_user = auth.uid() then raise exception 'You cannot remove your own agency access'; end if;
  select m.role into target_role from public.agency_members m
  where m.agency_id = target_agency and m.user_id = target_user;
  if target_role is null then raise exception 'Agency member not found'; end if;
  if target_role = 'owner' then raise exception 'The agency owner cannot be removed'; end if;
  delete from public.agency_members
  where agency_id = target_agency and user_id = target_user and user_id <> (select auth.uid());
  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then raise exception 'You are not allowed to remove this member'; end if;
end;
$$;
revoke all on function public.update_agency_member_role(uuid, uuid, text) from public, anon;
revoke all on function public.remove_agency_member(uuid, uuid) from public, anon;
grant execute on function public.update_agency_member_role(uuid, uuid, text) to authenticated;
grant execute on function public.remove_agency_member(uuid, uuid) to authenticated;
