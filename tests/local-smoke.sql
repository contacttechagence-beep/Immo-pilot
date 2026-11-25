-- Read-only structural smoke tests for the local Supabase stack.
-- Run only against the disposable local database after supabase db reset.
do $$
declare
  tbl text;
  expected_tables text[] := array['agencies','agency_members','prospects','activities','properties','mandates'];
  policy_count integer;
begin
  foreach tbl in array expected_tables loop
    if to_regclass('public.' || tbl) is null then
      raise exception 'Missing expected table public.%', tbl;
    end if;
    if not exists (
      select 1 from pg_class c
      where c.oid = to_regclass('public.' || tbl) and c.relrowsecurity
    ) then
      raise exception 'RLS is not enabled on public.%', tbl;
    end if;
  end loop;

  select count(*) into policy_count
  from pg_policies
  where schemaname = 'public'
    and tablename in ('properties','mandates')
    and policyname in (
      'Members can read properties','Members can create properties',
      'Members can update properties','Members can delete properties',
      'Members can read mandates','Members can create mandates',
      'Members can update mandates','Members can delete mandates'
    );
  if policy_count <> 8 then
    raise exception 'Expected 8 property/mandate RLS policies, found %', policy_count;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'mandates_property_agency_fk'
      and conrelid = 'public.mandates'::regclass
  ) then
    raise exception 'Missing composite mandate/property/agency foreign key';
  end if;

  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'is_agency_member'
  ) then
    raise exception 'Missing private.is_agency_member';
  end if;
end $$;

select
  (select count(*) from information_schema.tables
   where table_schema='public' and table_name in ('agencies','agency_members','prospects','activities','properties','mandates')) as expected_tables,
  (select count(*) from pg_policies
   where schemaname='public' and tablename in ('properties','mandates')) as property_mandate_policies;
