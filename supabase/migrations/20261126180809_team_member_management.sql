-- ImmoPilot team administration: safe member listing, role changes and removal.
-- Invitations require a separate server-side Auth Admin and email-delivery workflow.

create or replace function public.list_agency_members(target_agency uuid)
returns table (user_id uuid, email text, role text, created_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare actor_role text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select m.role into actor_role from public.agency_members m
  where m.agency_id = target_agency and m.user_id = auth.uid();
  if actor_role is null then raise exception 'Agency membership required'; end if;
  if actor_role not in ('owner', 'admin') then raise exception 'Agency administrator privileges required'; end if;
  return query
  select m.user_id, u.email::text, m.role, m.created_at
  from public.agency_members m
  join auth.users u on u.id = m.user_id
  where m.agency_id = target_agency
  order by case m.role when 'owner' then 0 when 'admin' then 1 else 2 end, m.created_at asc;
end;
$$;

create or replace function public.update_agency_member_role(target_agency uuid, target_user uuid, new_role text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare actor_role text; target_role text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if target_user = auth.uid() then raise exception 'You cannot change your own agency role'; end if;
  if new_role not in ('admin', 'agent') then raise exception 'Unsupported agency role'; end if;
  select m.role into actor_role from public.agency_members m
  where m.agency_id = target_agency and m.user_id = auth.uid();
  if actor_role <> 'owner' then raise exception 'Only the agency owner can change administrator roles'; end if;
  select m.role into target_role from public.agency_members m
  where m.agency_id = target_agency and m.user_id = target_user for update;
  if target_role is null then raise exception 'Agency member not found'; end if;
  if target_role = 'owner' then raise exception 'The agency owner role cannot be changed here'; end if;
  update public.agency_members set role = new_role
  where agency_id = target_agency and user_id = target_user;
end;
$$;

create or replace function public.remove_agency_member(target_agency uuid, target_user uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare actor_role text; target_role text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if target_user = auth.uid() then raise exception 'You cannot remove your own agency access'; end if;
  select m.role into actor_role from public.agency_members m
  where m.agency_id = target_agency and m.user_id = auth.uid();
  if actor_role not in ('owner', 'admin') then raise exception 'Agency administrator privileges required'; end if;
  select m.role into target_role from public.agency_members m
  where m.agency_id = target_agency and m.user_id = target_user for update;
  if target_role is null then raise exception 'Agency member not found'; end if;
  if target_role = 'owner' then raise exception 'The agency owner cannot be removed'; end if;
  if actor_role = 'admin' and target_role <> 'agent' then raise exception 'Administrators can only remove agents'; end if;
  delete from public.agency_members where agency_id = target_agency and user_id = target_user;
end;
$$;

revoke all on function public.list_agency_members(uuid) from public, anon;
revoke all on function public.update_agency_member_role(uuid, uuid, text) from public, anon;
revoke all on function public.remove_agency_member(uuid, uuid) from public, anon;
grant execute on function public.list_agency_members(uuid) to authenticated;
grant execute on function public.update_agency_member_role(uuid, uuid, text) to authenticated;
grant execute on function public.remove_agency_member(uuid, uuid) to authenticated;
