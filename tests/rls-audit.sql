-- ImmoPilot RLS catalog audit.
-- Read-only: checks deployed policy/function configuration; creates or modifies no data.
-- Run with a database role allowed to inspect PostgreSQL catalogs.

do $audit$
declare
  t text;
  expected text[] := array['agencies','agency_members','prospects','activities'];
  required_policy record;
  missing_count integer;
begin
  foreach t in array expected loop
    if not coalesce((select c.relrowsecurity
                     from pg_class c
                     join pg_namespace n on n.oid = c.relnamespace
                     where n.nspname = 'public' and c.relname = t), false) then
      raise exception 'RLS is not enabled on public.%', t;
    end if;
  end loop;

  for required_policy in
    select * from (values
      ('agencies','SELECT','Members can read their agencies','private.is_agency_member'),
      ('agencies','UPDATE','Agency admins can update their agency','private.is_agency_admin'),
      ('agency_members','SELECT','Members can read agency membership','private.is_agency_member'),
      ('prospects','SELECT','Members can read prospects','private.is_agency_member'),
      ('prospects','INSERT','Members can create prospects','private.is_agency_member'),
      ('prospects','UPDATE','Members can update prospects','private.is_agency_member'),
      ('prospects','DELETE','Members can delete prospects','private.is_agency_member'),
      ('activities','SELECT','Members can read activities','private.is_agency_member'),
      ('activities','INSERT','Members can create activities','private.is_agency_member'),
      ('activities','UPDATE','Members can update activities','private.is_agency_member'),
      ('activities','DELETE','Members can delete activities','private.is_agency_member')
    ) as p(tablename, cmd, policyname, predicate)
  loop
    select count(*) into missing_count
    from pg_policies p
    where p.schemaname = 'public'
      and p.tablename = required_policy.tablename
      and p.cmd = required_policy.cmd
      and p.policyname = required_policy.policyname
      and p.roles @> array['authenticated']::name[]
      and coalesce(p.qual, '') || ' ' || coalesce(p.with_check, '') like '%' || required_policy.predicate || '%';

    if missing_count = 0 then
      raise exception 'Missing or unexpected policy: public.%, % (%)',
        required_policy.tablename, required_policy.policyname, required_policy.cmd;
    end if;
  end loop;

  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private'
      and p.proname = 'is_agency_member'
      and p.prosecdef
      and coalesce(array_to_string(p.proconfig, ','), '') like '%search_path=%'
      and coalesce(array_to_string(p.proconfig, ','), '') like '%search_path=""%'
      and pg_get_functiondef(p.oid) like '%auth.uid()%'
  ) then
    raise exception 'private.is_agency_member must remain SECURITY DEFINER, use an empty search_path, and bind membership to auth.uid()';
  end if;

  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'create_agency'
      and p.prosecdef
      and coalesce(array_to_string(p.proconfig, ','), '') like '%search_path=""%'
      and pg_get_functiondef(p.oid) like '%auth.uid() is null%'
  ) then
    raise exception 'public.create_agency is missing its SECURITY DEFINER hardening/authentication guard';
  end if;

  raise notice 'ImmoPilot RLS catalog audit passed. This does not replace multi-user runtime isolation tests.';
end
$audit$;
