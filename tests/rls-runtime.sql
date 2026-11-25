-- Runtime RLS integration test. Runs only against disposable local Supabase and rolls back all fixtures.
begin;

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data)
values
 ('10000000-0000-4000-8000-000000000001','authenticated','authenticated','rls-a@immopilot.test','',now(),'{}','{}'),
 ('10000000-0000-4000-8000-000000000002','authenticated','authenticated','rls-b@immopilot.test','',now(),'{}','{}');

insert into public.agencies(id,name) values
 ('20000000-0000-4000-8000-000000000001','Agence test A'),
 ('20000000-0000-4000-8000-000000000002','Agence test B');

insert into public.agency_members(agency_id,user_id,role) values
 ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','owner'),
 ('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002','owner');

insert into public.properties(id,agency_id,reference,property_type,transaction_type,created_by)
values
 ('30000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','TEST-A','Appartement','Vente','10000000-0000-4000-8000-000000000001'),
 ('30000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000002','TEST-B','Maison','Vente','10000000-0000-4000-8000-000000000002');

insert into public.mandates(id,agency_id,property_id,mandate_type,mandate_number,created_by)
values ('40000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','Simple','MAND-A','10000000-0000-4000-8000-000000000001');

set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}',true);

do $test$
declare n integer;
begin
  select count(*) into n from public.properties;
  if n <> 1 then raise exception 'RLS leak: user A can see % properties; expected 1', n; end if;
  select count(*) into n from public.mandates;
  if n <> 1 then raise exception 'RLS leak: user A can see % mandates; expected 1', n; end if;

  insert into public.properties(agency_id,reference,property_type,transaction_type)
  values ('20000000-0000-4000-8000-000000000001','TEST-A2','Appartement','Vente');
  if not exists (select 1 from public.properties where reference='TEST-A2') then
    raise exception 'Agency member could not create own-agency property';
  end if;

  insert into public.mandates(agency_id,property_id,mandate_type,mandate_number)
  values ('20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','Exclusif','MAND-A2');
  update public.mandates set notes='Test de mise à jour' where mandate_number='MAND-A2';
  if not exists (select 1 from public.mandates where mandate_number='MAND-A2' and notes='Test de mise à jour') then
    raise exception 'Agency member could not create/update own-agency mandate';
  end if;
  delete from public.mandates where mandate_number='MAND-A2';
  if exists (select 1 from public.mandates where mandate_number='MAND-A2') then
    raise exception 'Agency member could not delete own-agency mandate';
  end if;

  update public.properties set city='Paris' where id='30000000-0000-4000-8000-000000000001';
  if not exists (select 1 from public.properties where id='30000000-0000-4000-8000-000000000001' and city='Paris') then
    raise exception 'Agency member could not update own-agency property';
  end if;

  update public.properties set city='Intrusion' where id='30000000-0000-4000-8000-000000000002';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'RLS failure: user A updated agency B property'; end if;

  begin
    insert into public.properties(agency_id,reference,property_type,transaction_type)
    values ('20000000-0000-4000-8000-000000000002','INTRUSION','Appartement','Vente');
    raise exception 'RLS failure: user A inserted property into agency B';
  exception when insufficient_privilege then
    null;
  end;

  begin
    insert into public.mandates(agency_id,property_id,mandate_type,mandate_number)
    values ('20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000002','Simple','CROSS-AGENCY');
    raise exception 'Integrity failure: mandate linked to another agency property';
  exception when foreign_key_violation then
    null;
  end;

  delete from public.properties where reference='TEST-A2';
  if exists (select 1 from public.properties where reference='TEST-A2') then
    raise exception 'Agency member could not delete own-agency property';
  end if;
end
$test$;

rollback;
