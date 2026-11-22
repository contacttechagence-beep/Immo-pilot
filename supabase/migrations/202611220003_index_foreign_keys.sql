-- Indexer les colonnes des clés étrangères signalées par Supabase Advisors.
create index if not exists prospects_created_by_idx on public.prospects(created_by);
create index if not exists activities_created_by_idx on public.activities(created_by);
create index if not exists activities_prospect_agency_idx on public.activities(prospect_id, agency_id);
