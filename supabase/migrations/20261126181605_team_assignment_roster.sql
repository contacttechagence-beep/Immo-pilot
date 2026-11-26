-- Allow all agency members to see an assignable roster while masking email addresses
-- for non-administrators. Owners/admins retain email visibility in the Team screen.
create or replace function public.list_agency_members(target_agency uuid)
returns table (user_id uuid, email text, role text, created_at timestamptz)
language plpgsql stable security definer set search_path = ''
as $$
declare actor_role text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select m.role into actor_role from public.agency_members m
  where m.agency_id = target_agency and m.user_id = auth.uid();
  if actor_role is null then raise exception 'Agency membership required'; end if;
  return query
  select m.user_id,
    case when actor_role in ('owner', 'admin') then u.email::text
         else 'Membre ' || left(m.user_id::text, 8) end,
    m.role, m.created_at
  from public.agency_members m join auth.users u on u.id = m.user_id
  where m.agency_id = target_agency
  order by case m.role when 'owner' then 0 when 'admin' then 1 else 2 end, m.created_at asc;
end;
$$;
revoke all on function public.list_agency_members(uuid) from public, anon;
grant execute on function public.list_agency_members(uuid) to authenticated;
