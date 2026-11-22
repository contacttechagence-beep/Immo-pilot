-- Durcissement des privilèges après création du schéma initial.
-- Retire les privilèges par défaut éventuellement accordés au rôle authenticated.
revoke all on public.agencies, public.agency_members, public.prospects, public.activities from anon, authenticated;

-- Accès minimaux nécessaires au fonctionnement de l'application.
grant select, update on public.agencies to authenticated;
grant select on public.agency_members to authenticated;
grant select, insert, update, delete on public.prospects to authenticated;
grant select, insert, update, delete on public.activities to authenticated;

-- La fonction trigger n'a pas vocation à être appelée directement par l'API.
revoke all on function public.set_updated_at() from public, anon, authenticated;

-- Création d'agence réservée aux utilisateurs connectés.
-- La fonction SECURITY DEFINER vérifie auth.uid() et utilise un search_path vide.
revoke all on function public.create_agency(text) from public, anon;
grant execute on function public.create_agency(text) to authenticated;
