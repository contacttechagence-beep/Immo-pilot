# ImmoPilot — état du développement accéléré

Date de l'audit : 2026-11-22
Branche de référence : `main`
Commit de référence : `3ccde847d4a1cec7d85edc9f4e4c033d016475f5`

## Sauvegarde et environnement

- Branche de sauvegarde créée : `backup/pre-accelerated-2026-11-22`.
- Branche de développement créée : `develop/accelerated`.
- Les deux branches pointent sur le commit de référence ci-dessus.
- La branche `main` et le site publié n'ont pas été modifiés.
- Aucun changement de schéma n'a été appliqué à la base de production.
- Une branche Supabase de développement n'a pas été créée : l'outil demande une confirmation préalable du coût et l'identifiant de l'organisation. Ne pas engager de frais sans accord explicite.

## État technique observé

- Front statique : `index.html` et `app.html`.
- Backend : Supabase Auth et PostgreSQL.
- Tables métier : `agencies`, `agency_members`, `prospects`, `activities`.
- Les quatre tables publiques ont RLS activé.
- Les politiques utilisent l'appartenance à l'agence ; les créations vérifient également `created_by = auth.uid()`.
- Trois migrations sont enregistrées : schéma initial, permissions minimales, index de clés étrangères.
- Le dernier workflow GitHub Pages observé est terminé avec succès.
- Les données observées sont limitées (2 agences, 2 membres, 1 prospect, 2 activités) ; cela ne constitue pas un test d'isolation.

## Alertes à traiter

1. Supabase Advisor signale `public.create_agency(text)` : fonction `SECURITY DEFINER` exécutable par les utilisateurs authentifiés. Le code vérifie `auth.uid()`, valide le nom et fixe un `search_path` vide. Cette fonction est nécessaire au parcours de première agence, mais doit être revue et testée avant toute modification.
2. La protection des mots de passe compromis est désactivée dans Supabase Auth.
3. Les index `prospects_created_by_idx` et `activities_created_by_idx` sont signalés comme inutilisés sur cette petite base de test. Ne pas les supprimer avant mesure avec des données et requêtes représentatives.
4. Les branches GitHub ne sont pas protégées.
5. L'isolation entre deux comptes appartenant à deux agences distinctes n'a pas encore été testée de bout en bout.
6. L'interface expose quatre statuts tandis que la contrainte SQL autorise aussi `Perdu`. Harmonisation à effectuer sans perte de données ni suppression du statut.

## Plan d'exécution

### Lot A — sécurité et qualité
- Configurer une branche Supabase isolée après validation de son coût.
- Ajouter des tests automatisés RLS avec deux utilisateurs et deux agences fictives.
- Vérifier les droits SQL, les fonctions privilégiées et les flux Auth.
- Activer la protection contre les mots de passe compromis après vérification de la configuration Auth.
- Ajouter des contrôles de validation et tests automatisés au workflow CI.
- Harmoniser les statuts front/base de données.

### Lot B — CRM et métier immobilier
- Fiches clients et prospects enrichies.
- Biens immobiliers, mandats et dossiers.
- Tâches, rendez-vous, calendrier et notifications.
- Historique et documents liés aux dossiers.

### Lot C — équipes et multi-agences
- Invitations, gestion des membres et rôles.
- Permissions et administration d'agence.
- Tests d'isolation et journaux d'audit.

### Lot D — IA et intégrations
- Fonctions IA via serveur/Edge Functions et secrets côté serveur.
- Génération de brouillons et synthèses avec validation humaine.
- Messagerie, calendriers et intégrations tierces.

### Lot E — SaaS commercial
- Abonnements, paiements, facturation, quotas et gestion des résiliations.
- Observabilité, sauvegardes/restauration, conformité RGPD, tests de charge et préparation de production.

## Règles de livraison

- Développer sur `develop/accelerated`, jamais directement sur `main`.
- Préserver les fonctionnalités existantes.
- Toute migration doit être versionnée et testée en environnement isolé avant production.
- Toute modification sensible doit être vérifiée par un test reproductible.
- Ne jamais exposer de clé `service_role`, de secret ou de données personnelles dans le dépôt.
