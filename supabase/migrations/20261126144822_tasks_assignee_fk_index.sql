-- Index supporting the composite agency-member assignment foreign key.
create index if not exists tasks_assigned_member_idx on public.tasks(agency_id, assigned_to);
