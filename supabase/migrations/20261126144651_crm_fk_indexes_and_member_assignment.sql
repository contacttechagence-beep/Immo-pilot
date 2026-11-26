-- Cover the new foreign keys and ensure task assignees are members of the same agency.
create index if not exists contacts_created_by_idx on public.contacts(created_by);
create index if not exists properties_created_by_idx on public.properties(created_by);
create index if not exists mandates_created_by_idx on public.mandates(created_by);
create index if not exists mandates_owner_contact_agency_idx on public.mandates(owner_contact_id, agency_id);
create index if not exists prospects_contact_agency_idx on public.prospects(contact_id, agency_id);
create index if not exists tasks_created_by_idx on public.tasks(created_by);
create index if not exists tasks_contact_agency_idx on public.tasks(contact_id, agency_id);
create index if not exists tasks_prospect_agency_idx on public.tasks(prospect_id, agency_id);
create index if not exists tasks_property_agency_idx on public.tasks(property_id, agency_id);
alter table public.tasks drop constraint if exists tasks_assigned_to_fkey;
alter table public.tasks drop constraint if exists tasks_assigned_member_fk;
alter table public.tasks add constraint tasks_assigned_member_fk
  foreign key (agency_id, assigned_to)
  references public.agency_members(agency_id, user_id)
  on delete set null (assigned_to);
