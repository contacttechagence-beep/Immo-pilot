revoke all on table public.documents from anon, public;
grant select, insert, update, delete on table public.documents to authenticated;
