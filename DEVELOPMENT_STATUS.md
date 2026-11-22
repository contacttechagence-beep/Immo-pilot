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
6. L'interface expose désormais les cinq statuts de la contrainte SQL (`Nouveau`, `À contacter`, `En cours`, `Converti`, `Perdu`). Le statut `Perdu` est disponible dans le filtre et le formulaire, comptabilisé séparément et exclu des rappels actifs.

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


## Correctif réalisé sur `develop/accelerated` (2026-11-22)

- Alignement de l'interface CRM avec le statut SQL `Perdu` : filtre, formulaire, badge, compteur dédié.
- Les prospects `Perdu` ne sont plus présentés comme des actions commerciales encore actives dans les rappels.
- Vérification effectuée : fichier relu depuis GitHub après commit et présence des éléments modifiés confirmée.
- Vérification non effectuée : exécution dans un navigateur et test connecté à Supabase. Ce correctif reste donc à valider fonctionnellement avant fusion dans `main`.


## CI frontend ajouté (2026-11-22)

- Workflow `.github/workflows/validate.yml` : contrôle à chaque push sur `develop/accelerated` et lors des pull requests vers `main`.
- Script `tests/validate.mjs` : vérifie le doctype, les identifiants HTML en double, la syntaxe des scripts JavaScript intégrés et la présence des fonctions CRM essentielles.
- Exécution GitHub Actions sur le commit `3b4d5ae9d2040287df992ddc7b6a443ec8fe36ef` : **SUCCÈS** (run 45062315079).
- Une première exécution a échoué à cause d'une expression régulière mal échappée dans le script de test ; le défaut a été corrigé puis le workflow a été relancé avec succès.
- Ces contrôles sont statiques : ils ne remplacent pas les tests de navigateur, les tests Auth/Supabase ni les tests d'isolation RLS.


## Audit RLS catalogue ajouté (2026-11-22)

- Ajout de `tests/rls-audit.sql` : audit en lecture seule des quatre activations RLS, des 11 politiques attendues et des garde-fous des fonctions `private.is_agency_member` et `public.create_agency`.
- L'audit SQL a été exécuté sur le projet Supabase connecté : **aucune exception**, donc les contrôles du catalogue ont passé.
- CI mis à jour pour vérifier la présence des contrôles RLS dans le dépôt.
- GitHub Actions sur le commit `cbc7435a082413e11e9f112f32ced5b34e8c6041` : **SUCCÈS**, run 45062507649.
- Limite importante : cet audit inspecte la configuration SQL ; il ne simule pas deux utilisateurs authentifiés et ne prouve pas l'isolation réelle des données entre agences.
- Aucune donnée, table, politique ou fonction de production n'a été modifiée par cet audit.
