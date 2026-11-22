-- ImmoPilot V2 — schéma initial multi-agences
-- À exécuter dans un projet Supabase neuf, via SQL Editor ou Supabase CLI.
-- Ne contient aucune clé ni donnée réelle.

create extension if not exists pgcrypto;

create schema if not exists private;

create table if not exists public.agencies (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 2 and 120),
  created_at timestamptz not null default now()
);

create table if not exists public.agency_members (
  agency_id uuid not null references public.agencies(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'agent' check (role in ('owner', 'admin', 'agent')),
  created_at timestamptz not null default now(),
  primary key (agency_id, user_id)
);

create index if not exists agency_members_user_id_idx on public.agency_members(user_id);

create table if not exists public.prospects (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.agencies(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 120),
  email text,
  phone text,
  project_type text not null default 'Autre',
  area text,
  budget numeric(14,2) check (budget is null or budget >= 0),
  status text not null default 'Nouveau'
    check (status in ('Nouveau', 'À contacter', 'En cours', 'Converti', 'Perdu')),
  next_action_at date,
  notes text,
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, agency_id)
);

create index if not exists prospects_agency_created_idx
  on public.prospects(agency_id, created_at desc);
create index if not exists prospects_agency_status_idx
  on public.prospects(agency_id, status);

create table if not exists public.activities (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.agencies(id) on delete cascade,
  prospect_id uuid not null,
  activity_type text not null check (activity_type in ('note', 'call', 'email', 'meeting', 'status_change')),
  content text not null check (char_length(trim(content)) between 1 and 4000),
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  constraint activities_prospect_agency_fk
    foreign key (prospect_id, agency_id)
    references public.prospects(id, agency_id) on delete cascade
);

create index if not exists activities_agency_prospect_idx
  on public.activities(agency_id, prospect_id, created_at desc);

-- Fonction privée utilisée par les politiques RLS. SECURITY DEFINER évite
-- une récursion de politique lors de la lecture de agency_members.
create or replace function private.is_agency_member(target_agency uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.agency_members m
    where m.agency_id = target_agency
      and m.user_id = (select auth.uid())
  );
$$;

create or replace function private.is_agency_admin(target_agency uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.agency_members m
    where m.agency_id = target_agency
      and m.user_id = (select auth.uid())
      and m.role in ('owner', 'admin')
  );
$$;

revoke all on function private.is_agency_member(uuid) from public, anon;
revoke all on function private.is_agency_admin(uuid) from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.is_agency_member(uuid) to authenticated;
grant execute on function private.is_agency_admin(uuid) to authenticated;

-- Création atomique de la première agence et de son propriétaire.
create or replace function public.create_agency(agency_name text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_agency_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if char_length(trim(coalesce(agency_name, ''))) not between 2 and 120 then
    raise exception 'Agency name must contain between 2 and 120 characters';
  end if;

  insert into public.agencies(name)
  values (trim(agency_name))
  returning id into new_agency_id;

  insert into public.agency_members(agency_id, user_id, role)
  values (new_agency_id, auth.uid(), 'owner');

  return new_agency_id;
end;
$$;

revoke all on function public.create_agency(text) from public, anon;
grant execute on function public.create_agency(text) to authenticated;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists prospects_set_updated_at on public.prospects;
create trigger prospects_set_updated_at
before update on public.prospects
for each row execute function public.set_updated_at();

alter table public.agencies enable row level security;
alter table public.agency_members enable row level security;
alter table public.prospects enable row level security;
alter table public.activities enable row level security;

drop policy if exists "Members can read their agencies" on public.agencies;
create policy "Members can read their agencies"
on public.agencies for select to authenticated
using (private.is_agency_member(id));

drop policy if exists "Agency admins can update their agency" on public.agencies;
create policy "Agency admins can update their agency"
on public.agencies for update to authenticated
using (private.is_agency_admin(id))
with check (private.is_agency_admin(id));

drop policy if exists "Members can read agency membership" on public.agency_members;
create policy "Members can read agency membership"
on public.agency_members for select to authenticated
using (private.is_agency_member(agency_id));

-- Les ajouts/retraits de membres seront faits par un flux serveur contrôlé,
-- pas par une insertion libre depuis le navigateur.

drop policy if exists "Members can read prospects" on public.prospects;
create policy "Members can read prospects"
on public.prospects for select to authenticated
using (private.is_agency_member(agency_id));

drop policy if exists "Members can create prospects" on public.prospects;
create policy "Members can create prospects"
on public.prospects for insert to authenticated
with check (
  private.is_agency_member(agency_id)
  and created_by = (select auth.uid())
);

drop policy if exists "Members can update prospects" on public.prospects;
create policy "Members can update prospects"
on public.prospects for update to authenticated
using (private.is_agency_member(agency_id))
with check (private.is_agency_member(agency_id));

drop policy if exists "Members can delete prospects" on public.prospects;
create policy "Members can delete prospects"
on public.prospects for delete to authenticated
using (private.is_agency_member(agency_id));

drop policy if exists "Members can read activities" on public.activities;
create policy "Members can read activities"
on public.activities for select to authenticated
using (private.is_agency_member(agency_id));

drop policy if exists "Members can create activities" on public.activities;
create policy "Members can create activities"
on public.activities for insert to authenticated
with check (
  private.is_agency_member(agency_id)
  and created_by = (select auth.uid())
);

drop policy if exists "Members can update activities" on public.activities;
create policy "Members can update activities"
on public.activities for update to authenticated
using (private.is_agency_member(agency_id))
with check (private.is_agency_member(agency_id));

drop policy if exists "Members can delete activities" on public.activities;
create policy "Members can delete activities"
on public.activities for delete to authenticated
using (private.is_agency_member(agency_id));

-- Aucun accès anonyme. Les droits SQL de base sont explicitement limités.
revoke all on public.agencies, public.agency_members, public.prospects, public.activities from anon;
grant select, update on public.agencies to authenticated;
grant select on public.agency_members to authenticated;
grant select, insert, update, delete on public.prospects to authenticated;
grant select, insert, update, delete on public.activities to authenticated;
