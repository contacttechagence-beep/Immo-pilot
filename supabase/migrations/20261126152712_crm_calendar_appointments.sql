create table public.appointments (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.agencies(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 2 and 160),
  description text,
  event_type text not null default 'Rendez-vous' check (event_type in ('Rendez-vous','Visite','Appel','Réunion','État des lieux','Signature','Autre')),
  status text not null default 'Planifié' check (status in ('Planifié','Confirmé','Terminé','Annulé')),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  all_day boolean not null default false,
  location text,
  prospect_id uuid,
  contact_id uuid,
  property_id uuid,
  assigned_to uuid not null default auth.uid(),
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, agency_id),
  constraint appointments_dates_check check (ends_at > starts_at),
  constraint appointments_prospect_agency_fk foreign key (prospect_id, agency_id) references public.prospects(id, agency_id) on delete set null (prospect_id),
  constraint appointments_contact_agency_fk foreign key (contact_id, agency_id) references public.contacts(id, agency_id) on delete set null (contact_id),
  constraint appointments_property_agency_fk foreign key (property_id, agency_id) references public.properties(id, agency_id) on delete set null (property_id),
  constraint appointments_assigned_member_fk foreign key (agency_id, assigned_to) references public.agency_members(agency_id, user_id) on delete restrict
);
create index appointments_agency_start_idx on public.appointments(agency_id, starts_at);
create index appointments_assignee_start_idx on public.appointments(agency_id, assigned_to, starts_at);
create index appointments_prospect_idx on public.appointments(prospect_id, agency_id) where prospect_id is not null;
create index appointments_contact_idx on public.appointments(contact_id, agency_id) where contact_id is not null;
create index appointments_property_idx on public.appointments(property_id, agency_id) where property_id is not null;
create index appointments_created_by_idx on public.appointments(created_by);
alter table public.appointments enable row level security;
grant select, insert, update, delete on public.appointments to authenticated;
revoke all on public.appointments from anon, public;
create policy appointments_members_select on public.appointments for select to authenticated using (private.is_agency_member(agency_id));
create policy appointments_members_insert on public.appointments for insert to authenticated with check (private.is_agency_member(agency_id) and created_by=(select auth.uid()) and assigned_to in (select am.user_id from public.agency_members am where am.agency_id=appointments.agency_id));
create policy appointments_members_update on public.appointments for update to authenticated using (private.is_agency_member(agency_id)) with check (private.is_agency_member(agency_id) and assigned_to in (select am.user_id from public.agency_members am where am.agency_id=appointments.agency_id));
create policy appointments_members_delete on public.appointments for delete to authenticated using (private.is_agency_member(agency_id));
create trigger appointments_set_updated_at before update on public.appointments for each row execute function public.set_updated_at();
