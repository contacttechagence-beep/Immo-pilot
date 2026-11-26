-- ImmoPilot CRM and property-management foundation
-- Additive migration: preserves the existing prospects and activities data.

create table if not exists public.contacts (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.agencies(id) on delete cascade,
  first_name text not null check (char_length(trim(first_name)) between 1 and 80),
  last_name text not null check (char_length(trim(last_name)) between 1 and 80),
  email text,
  phone text,
  contact_type text not null default 'other' check (contact_type in ('buyer','seller','landlord','tenant','notary','other')),
  notes text,
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, agency_id)
);
create index if not exists contacts_agency_name_idx on public.contacts(agency_id, last_name, first_name);

create table if not exists public.properties (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.agencies(id) on delete cascade,
  reference text not null,
  title text not null check (char_length(trim(title)) between 2 and 160),
  property_type text not null default 'Appartement' check (property_type in ('Appartement','Maison','Terrain','Immeuble','Local commercial','Parking','Autre')),
  transaction_type text not null default 'Vente' check (transaction_type in ('Vente','Location')),
  address text,
  postal_code text,
  city text,
  price numeric(14,2) check (price is null or price >= 0),
  surface_area numeric(10,2) check (surface_area is null or surface_area > 0),
  rooms integer check (rooms is null or rooms >= 0),
  bedrooms integer check (bedrooms is null or bedrooms >= 0),
  status text not null default 'Disponible' check (status in ('Disponible','Sous offre','Loué','Vendu','Retiré')),
  description text,
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, agency_id),
  unique (agency_id, reference)
);
create index if not exists properties_agency_status_idx on public.properties(agency_id, status);
create index if not exists properties_agency_city_idx on public.properties(agency_id, city);

create table if not exists public.mandates (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.agencies(id) on delete cascade,
  property_id uuid not null,
  owner_contact_id uuid,
  reference text not null,
  mandate_type text not null default 'Simple' check (mandate_type in ('Simple','Exclusif','Semi-exclusif','Gestion locative')),
  status text not null default 'Brouillon' check (status in ('Brouillon','Actif','Suspendu','Terminé','Résilié')),
  start_date date,
  end_date date,
  fee_rate numeric(5,2) check (fee_rate is null or fee_rate between 0 and 100),
  notes text,
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, agency_id),
  unique (agency_id, reference),
  constraint mandates_property_agency_fk foreign key (property_id, agency_id) references public.properties(id, agency_id) on delete cascade,
  constraint mandates_owner_agency_fk foreign key (owner_contact_id, agency_id) references public.contacts(id, agency_id) on delete set null (owner_contact_id),
  constraint mandates_dates_check check (end_date is null or start_date is null or end_date >= start_date)
);
create index if not exists mandates_agency_status_idx on public.mandates(agency_id, status);
create index if not exists mandates_property_idx on public.mandates(property_id, agency_id);

create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.agencies(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 2 and 160),
  description text,
  due_at timestamptz,
  status text not null default 'À faire' check (status in ('À faire','En cours','Terminée','Annulée')),
  priority text not null default 'Normale' check (priority in ('Basse','Normale','Haute','Urgente')),
  assigned_to uuid references auth.users(id) on delete set null,
  prospect_id uuid,
  contact_id uuid,
  property_id uuid,
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint tasks_prospect_agency_fk foreign key (prospect_id, agency_id) references public.prospects(id, agency_id) on delete cascade,
  constraint tasks_contact_agency_fk foreign key (contact_id, agency_id) references public.contacts(id, agency_id) on delete cascade,
  constraint tasks_property_agency_fk foreign key (property_id, agency_id) references public.properties(id, agency_id) on delete cascade,
  constraint tasks_has_context check (prospect_id is not null or contact_id is not null or property_id is not null)
);
create index if not exists tasks_agency_due_idx on public.tasks(agency_id, status, due_at);
create index if not exists tasks_assigned_idx on public.tasks(assigned_to, agency_id);

alter table public.prospects add column if not exists contact_id uuid;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'prospects_contact_agency_fk') then
    alter table public.prospects add constraint prospects_contact_agency_fk
      foreign key (contact_id, agency_id) references public.contacts(id, agency_id) on delete set null (contact_id);
  end if;
end $$;

do $$ declare t text; begin
  foreach t in array array['contacts','properties','mandates','tasks'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists %I on public.%I', t || '_members_select', t);
    execute format('create policy %I on public.%I for select to authenticated using (private.is_agency_member(agency_id))', t || '_members_select', t);
    execute format('drop policy if exists %I on public.%I', t || '_members_insert', t);
    execute format('create policy %I on public.%I for insert to authenticated with check (private.is_agency_member(agency_id) and created_by = (select auth.uid()))', t || '_members_insert', t);
    execute format('drop policy if exists %I on public.%I', t || '_members_update', t);
    execute format('create policy %I on public.%I for update to authenticated using (private.is_agency_member(agency_id)) with check (private.is_agency_member(agency_id))', t || '_members_update', t);
    execute format('drop policy if exists %I on public.%I', t || '_members_delete', t);
    execute format('create policy %I on public.%I for delete to authenticated using (private.is_agency_member(agency_id))', t || '_members_delete', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    execute format('revoke all on public.%I from anon', t);
  end loop;
end $$;

drop trigger if exists contacts_set_updated_at on public.contacts;
create trigger contacts_set_updated_at before update on public.contacts for each row execute function public.set_updated_at();
drop trigger if exists properties_set_updated_at on public.properties;
create trigger properties_set_updated_at before update on public.properties for each row execute function public.set_updated_at();
drop trigger if exists mandates_set_updated_at on public.mandates;
create trigger mandates_set_updated_at before update on public.mandates for each row execute function public.set_updated_at();
drop trigger if exists tasks_set_updated_at on public.tasks;
create trigger tasks_set_updated_at before update on public.tasks for each row execute function public.set_updated_at();

grant select, insert, update, delete on public.prospects to authenticated;
