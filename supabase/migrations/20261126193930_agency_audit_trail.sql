-- Agency-scoped audit trail. Stores action metadata and changed field names only,
-- never the previous/new values of client or prospect data.
create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.agencies(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  entity_type text not null check (entity_type in ('prospects','activities','contacts','properties','mandates','tasks','appointments','documents')),
  entity_id uuid not null,
  action text not null check (action in ('insert','update','delete')),
  changed_fields text[] not null default '{}',
  created_at timestamptz not null default now()
);
create index if not exists audit_logs_agency_created_idx on public.audit_logs(agency_id,created_at desc);
create index if not exists audit_logs_entity_idx on public.audit_logs(agency_id,entity_type,entity_id);
alter table public.audit_logs enable row level security;
revoke all on public.audit_logs from public,anon;
grant select on public.audit_logs to authenticated;
drop policy if exists audit_logs_admin_read on public.audit_logs;
create policy audit_logs_admin_read on public.audit_logs for select to authenticated
using (private.is_agency_admin(agency_id));

create or replace function private.capture_agency_audit_log()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare old_row jsonb; new_row jsonb; target_agency uuid; target_entity uuid; changed text[];
excluded_fields text[] := array['id','agency_id','created_at','updated_at','created_by','uploaded_by'];
begin
  if tg_op='INSERT' then
    new_row:=to_jsonb(new); target_agency:=(new_row->>'agency_id')::uuid; target_entity:=(new_row->>'id')::uuid;
    select coalesce(array_agg(k.key order by k.key),array[]::text[]) into changed
    from jsonb_object_keys(new_row) as k(key) where not(k.key=any(excluded_fields));
  elsif tg_op='UPDATE' then
    old_row:=to_jsonb(old); new_row:=to_jsonb(new); target_agency:=(new_row->>'agency_id')::uuid; target_entity:=(new_row->>'id')::uuid;
    select coalesce(array_agg(n.key order by n.key),array[]::text[]) into changed
    from jsonb_each(new_row) as n(key,value)
    where old_row->n.key is distinct from n.value and not(n.key=any(excluded_fields));
    if cardinality(changed)=0 then return new; end if;
  else
    old_row:=to_jsonb(old); target_agency:=(old_row->>'agency_id')::uuid; target_entity:=(old_row->>'id')::uuid;
    select coalesce(array_agg(k.key order by k.key),array[]::text[]) into changed
    from jsonb_object_keys(old_row) as k(key) where not(k.key=any(excluded_fields));
  end if;
  if target_agency is not null and target_entity is not null then
    insert into public.audit_logs(agency_id,actor_id,entity_type,entity_id,action,changed_fields)
    values(target_agency,auth.uid(),tg_table_name,target_entity,lower(tg_op),changed);
  end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end;
$$;
revoke all on function private.capture_agency_audit_log() from public,anon,authenticated;

drop trigger if exists prospects_audit_log on public.prospects;
create trigger prospects_audit_log after insert or update or delete on public.prospects for each row execute function private.capture_agency_audit_log();
drop trigger if exists activities_audit_log on public.activities;
create trigger activities_audit_log after insert or update or delete on public.activities for each row execute function private.capture_agency_audit_log();
drop trigger if exists contacts_audit_log on public.contacts;
create trigger contacts_audit_log after insert or update or delete on public.contacts for each row execute function private.capture_agency_audit_log();
drop trigger if exists properties_audit_log on public.properties;
create trigger properties_audit_log after insert or update or delete on public.properties for each row execute function private.capture_agency_audit_log();
drop trigger if exists mandates_audit_log on public.mandates;
create trigger mandates_audit_log after insert or update or delete on public.mandates for each row execute function private.capture_agency_audit_log();
drop trigger if exists tasks_audit_log on public.tasks;
create trigger tasks_audit_log after insert or update or delete on public.tasks for each row execute function private.capture_agency_audit_log();
drop trigger if exists appointments_audit_log on public.appointments;
create trigger appointments_audit_log after insert or update or delete on public.appointments for each row execute function private.capture_agency_audit_log();
drop trigger if exists documents_audit_log on public.documents;
create trigger documents_audit_log after insert or update or delete on public.documents for each row execute function private.capture_agency_audit_log();
