-- Secure, shareable agency invitations without an external email provider.
-- The invitation link is created in-app and can be shared manually.
create table if not exists public.agency_invitations (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.agencies(id) on delete cascade,
  email text not null check (char_length(email) between 5 and 254),
  role text not null check (role in ('admin','agent')),
  token_hash text not null unique,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  accepted_at timestamptz,
  revoked_at timestamptz,
  constraint agency_invitations_expiry_check check (expires_at > created_at)
);
create index if not exists agency_invitations_agency_pending_idx
  on public.agency_invitations(agency_id, expires_at)
  where accepted_at is null and revoked_at is null;
alter table public.agency_invitations enable row level security;
revoke all on public.agency_invitations from public, anon, authenticated;

create or replace function public.create_agency_invitation(target_agency uuid, invite_email text, invite_role text default 'agent')
returns table(invitation_id uuid, invite_token text, expires_at timestamptz)
language plpgsql security definer set search_path = ''
as $$
declare actor_role text; normalized_email text; raw_token text; new_id uuid; expiry timestamptz;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  normalized_email := lower(btrim(coalesce(invite_email, '')));
  if char_length(normalized_email) < 5 or char_length(normalized_email) > 254
     or position('@' in normalized_email) < 2
     or position('.' in split_part(normalized_email, '@', 2)) < 2 then
    raise exception 'A valid email address is required';
  end if;
  if invite_role not in ('admin','agent') then raise exception 'Unsupported invitation role'; end if;
  select m.role into actor_role from public.agency_members m
  where m.agency_id = target_agency and m.user_id = auth.uid();
  if actor_role is null or actor_role not in ('owner','admin') then raise exception 'Agency administrator privileges required'; end if;
  if actor_role = 'admin' and invite_role <> 'agent' then raise exception 'Administrators can only invite agents'; end if;
  if exists (select 1 from public.agency_members m join auth.users u on u.id=m.user_id
    where m.agency_id=target_agency and lower(u.email)=normalized_email) then
    raise exception 'This account is already a member of the agency';
  end if;
  update public.agency_invitations set revoked_at=now()
  where agency_id=target_agency and lower(email)=normalized_email and accepted_at is null and revoked_at is null;
  raw_token := encode(extensions.gen_random_bytes(32),'hex');
  expiry := now()+interval '7 days';
  insert into public.agency_invitations(agency_id,email,role,token_hash,created_by,expires_at)
  values(target_agency,normalized_email,invite_role,
    encode(extensions.digest(convert_to(raw_token,'UTF8'),'sha256'),'hex'),auth.uid(),expiry)
  returning id into new_id;
  return query select new_id,raw_token,expiry;
end;
$$;

create or replace function public.list_agency_invitations(target_agency uuid)
returns table(invitation_id uuid,email text,role text,created_at timestamptz,expires_at timestamptz)
language plpgsql stable security definer set search_path = ''
as $$
declare actor_role text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select m.role into actor_role from public.agency_members m
  where m.agency_id=target_agency and m.user_id=auth.uid();
  if actor_role is null or actor_role not in ('owner','admin') then raise exception 'Agency administrator privileges required'; end if;
  return query select i.id,i.email,i.role,i.created_at,i.expires_at from public.agency_invitations i
  where i.agency_id=target_agency and i.accepted_at is null and i.revoked_at is null and i.expires_at>now()
  order by i.created_at desc;
end;
$$;

create or replace function public.revoke_agency_invitation(target_agency uuid,target_invitation uuid)
returns void language plpgsql security definer set search_path = ''
as $$
declare actor_role text; invitation_role text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select m.role into actor_role from public.agency_members m
  where m.agency_id=target_agency and m.user_id=auth.uid();
  if actor_role is null or actor_role not in ('owner','admin') then raise exception 'Agency administrator privileges required'; end if;
  select i.role into invitation_role from public.agency_invitations i
  where i.id=target_invitation and i.agency_id=target_agency and i.accepted_at is null and i.revoked_at is null for update;
  if invitation_role is null then raise exception 'Pending invitation not found'; end if;
  if actor_role='admin' and invitation_role<>'agent' then raise exception 'Administrators can only revoke agent invitations'; end if;
  update public.agency_invitations set revoked_at=now() where id=target_invitation and agency_id=target_agency;
end;
$$;

create or replace function public.accept_agency_invitation(invite_token text)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare actor_email text; email_verified timestamptz; invitation public.agency_invitations%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if invite_token is null or char_length(invite_token)<>64 then raise exception 'Invalid invitation link'; end if;
  select lower(u.email),u.email_confirmed_at into actor_email,email_verified from auth.users u where u.id=auth.uid();
  if actor_email is null or email_verified is null then raise exception 'Confirm your email address before accepting an invitation'; end if;
  select i.* into invitation from public.agency_invitations i
  where i.token_hash=encode(extensions.digest(convert_to(invite_token,'UTF8'),'sha256'),'hex') for update;
  if invitation.id is null or invitation.accepted_at is not null or invitation.revoked_at is not null or invitation.expires_at<=now() then
    raise exception 'This invitation is invalid, expired or already used';
  end if;
  if actor_email<>lower(invitation.email) then raise exception 'Sign in with the email address that received this invitation'; end if;
  if exists(select 1 from public.agency_members m where m.agency_id=invitation.agency_id and m.user_id=auth.uid()) then
    raise exception 'You are already a member of this agency';
  end if;
  insert into public.agency_members(agency_id,user_id,role) values(invitation.agency_id,auth.uid(),invitation.role);
  update public.agency_invitations set accepted_at=now() where id=invitation.id;
  return invitation.agency_id;
end;
$$;

revoke all on function public.create_agency_invitation(uuid,text,text) from public,anon;
revoke all on function public.list_agency_invitations(uuid) from public,anon;
revoke all on function public.revoke_agency_invitation(uuid,uuid) from public,anon;
revoke all on function public.accept_agency_invitation(text) from public,anon;
grant execute on function public.create_agency_invitation(uuid,text,text) to authenticated;
grant execute on function public.list_agency_invitations(uuid) to authenticated;
grant execute on function public.revoke_agency_invitation(uuid,uuid) to authenticated;
grant execute on function public.accept_agency_invitation(text) to authenticated;
