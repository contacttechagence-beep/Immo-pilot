-- ImmoPilot — module biens immobiliers et mandats
-- Migration additive : à appliquer uniquement sur un environnement de développement isolé
-- après validation du coût et exécution des tests. Ne pas exécuter directement en production.

create table if not exists public.properties (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.agencies(id) on delete cascade,
  reference text not null check (char_length(trim(reference)) between 1 and 40),
  property_type text not null check (property_type in ('Appartement','Maison','Terrain','Immeuble','Local commercial','Parking','Autre')),
  transaction_type text not null check (transaction_type in ('Vente','Location')),
  address text,
  postal_code text,
  city text,
  living_area numeric(10,2) check (living_area is null or living_area > 0),
  rooms integer check (rooms is null or rooms >= 0),
  asking_price numeric(14,2) check (asking_price is null or asking_price >= 0),
  status text not null default 'Disponible'
    check (status in ('Disponible','Sous offre','Sous compromis','Loué','Vendu','Retiré')),
  description text check (description is null or char_length(description) <= 5000),
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, agency_id),
  unique (agency_id, reference)
);

create index if not exists properties_agency_status_idx
  on public.properties(agency_id, status);
create index if not exists properties_agency_city_idx
  on public.properties(agency_id, city);

create table if not exists public.mandates (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.agencies(id) on delete cascade,
  property_id uuid not null,
  mandate_type text not null check (mandate_type in ('Simple','Exclusif','Semi-exclusif')),
  mandate_number text not null check (char_length(trim(mandate_number)) between 1 and 60),
  status text not null default 'Brouillon'
    check (status in ('Brouillon','Actif','Suspendu','Terminé','Résilié')),
  start_date date,
  end_date date,
  commission_rate numeric(5,2) check (commission_rate is null or commission_rate between 0 and 100),
  notes text check (notes is null or char_length(notes) <= 4000),
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint mandates_dates_check check (start_date is null or end_date is null or end_date >= start_date),
  constraint mandates_property_agency_fk
    foreign key (property_id, agency_id)
    references public.properties(id, agency_id) on delete cascade,
  unique (agency_id, mandate_number)
);

create index if not exists mandates_agency_status_idx
  on public.mandates(agency_id, status);
create index if not exists mandates_property_idx
  on public.mandates(property_id, agency_id);

drop trigger if exists properties_set_updated_at on public.properties;
create trigger properties_set_updated_at
before update on public.properties
for each row execute function public.set_updated_at();

drop trigger if exists mandates_set_updated_at on public.mandates;
create trigger mandates_set_updated_at
before update on public.mandates
for each row execute function public.set_updated_at();

alter table public.properties enable row level security;
alter table public.mandates enable row level security;

drop policy if exists "Members can read properties" on public.properties;
create policy "Members can read properties"
on public.properties for select to authenticated
using (private.is_agency_member(agency_id));

drop policy if exists "Members can create properties" on public.properties;
create policy "Members can create properties"
on public.properties for insert to authenticated
with check (
  private.is_agency_member(agency_id)
  and created_by = (select auth.uid())
);

drop policy if exists "Members can update properties" on public.properties;
create policy "Members can update properties"
on public.properties for update to authenticated
using (private.is_agency_member(agency_id))
with check (private.is_agency_member(agency_id));

drop policy if exists "Members can delete properties" on public.properties;
create policy "Members can delete properties"
on public.properties for delete to authenticated
using (private.is_agency_member(agency_id));

drop policy if exists "Members can read mandates" on public.mandates;
create policy "Members can read mandates"
on public.mandates for select to authenticated
using (private.is_agency_member(agency_id));

drop policy if exists "Members can create mandates" on public.mandates;
create policy "Members can create mandates"
on public.mandates for insert to authenticated
with check (
  private.is_agency_member(agency_id)
  and created_by = (select auth.uid())
);

drop policy if exists "Members can update mandates" on public.mandates;
create policy "Members can update mandates"
on public.mandates for update to authenticated
using (private.is_agency_member(agency_id))
with check (private.is_agency_member(agency_id));

drop policy if exists "Members can delete mandates" on public.mandates;
create policy "Members can delete mandates"
on public.mandates for delete to authenticated
using (private.is_agency_member(agency_id));

revoke all on public.properties, public.mandates from anon, authenticated;
grant select, insert, update, delete on public.properties, public.mandates to authenticated;
