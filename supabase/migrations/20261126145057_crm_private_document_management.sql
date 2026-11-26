create table public.documents (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.agencies(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 1 and 160),
  original_name text not null check (char_length(original_name) between 1 and 255),
  storage_path text not null unique,
  mime_type text not null,
  size_bytes bigint not null check (size_bytes > 0 and size_bytes <= 20971520),
  description text,
  prospect_id uuid,
  contact_id uuid,
  property_id uuid,
  mandate_id uuid,
  uploaded_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  constraint documents_id_agency_unique unique (id, agency_id),
  constraint documents_prospect_agency_fk foreign key (prospect_id, agency_id) references public.prospects(id, agency_id),
  constraint documents_contact_agency_fk foreign key (contact_id, agency_id) references public.contacts(id, agency_id),
  constraint documents_property_agency_fk foreign key (property_id, agency_id) references public.properties(id, agency_id),
  constraint documents_mandate_agency_fk foreign key (mandate_id, agency_id) references public.mandates(id, agency_id),
  constraint documents_storage_path_agency_check check (split_part(storage_path, '/', 1) = agency_id::text)
);
create index documents_agency_created_idx on public.documents(agency_id, created_at desc);
create index documents_prospect_agency_idx on public.documents(prospect_id, agency_id) where prospect_id is not null;
create index documents_contact_agency_idx on public.documents(contact_id, agency_id) where contact_id is not null;
create index documents_property_agency_idx on public.documents(property_id, agency_id) where property_id is not null;
create index documents_mandate_agency_idx on public.documents(mandate_id, agency_id) where mandate_id is not null;
alter table public.documents enable row level security;
grant select, insert, update, delete on public.documents to authenticated;
create policy "Agency members can read documents" on public.documents for select to authenticated
using (exists (select 1 from public.agency_members am where am.agency_id = documents.agency_id and am.user_id = (select auth.uid())));
create policy "Agency members can insert documents" on public.documents for insert to authenticated
with check (uploaded_by = (select auth.uid()) and exists (select 1 from public.agency_members am where am.agency_id = documents.agency_id and am.user_id = (select auth.uid())));
create policy "Agency members can update documents" on public.documents for update to authenticated
using (exists (select 1 from public.agency_members am where am.agency_id = documents.agency_id and am.user_id = (select auth.uid())))
with check (exists (select 1 from public.agency_members am where am.agency_id = documents.agency_id and am.user_id = (select auth.uid())));
create policy "Agency members can delete documents" on public.documents for delete to authenticated
using (exists (select 1 from public.agency_members am where am.agency_id = documents.agency_id and am.user_id = (select auth.uid())));
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('immopilot-documents','immopilot-documents',false,20971520,
array['application/pdf','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','text/csv','text/plain','image/jpeg','image/png','image/webp']);
create policy "ImmoPilot agency members can read documents" on storage.objects for select to authenticated
using (bucket_id='immopilot-documents' and exists (select 1 from public.agency_members am where am.agency_id::text=(storage.foldername(name))[1] and am.user_id=(select auth.uid())));
create policy "ImmoPilot agency members can upload documents" on storage.objects for insert to authenticated
with check (bucket_id='immopilot-documents' and exists (select 1 from public.agency_members am where am.agency_id::text=(storage.foldername(name))[1] and am.user_id=(select auth.uid())));
create policy "ImmoPilot agency members can delete documents" on storage.objects for delete to authenticated
using (bucket_id='immopilot-documents' and exists (select 1 from public.agency_members am where am.agency_id::text=(storage.foldername(name))[1] and am.user_id=(select auth.uid())));
