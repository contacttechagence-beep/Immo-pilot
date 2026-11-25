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

## Renforcement de l'audit RLS et CI (2026-11-22)

- Renforcement de `tests/rls-audit.sql` : les politiques INSERT sur `prospects` et `activities` doivent vérifier l'appartenance à l'agence et `created_by = auth.uid()`; les politiques UPDATE doivent vérifier l'appartenance dans `USING` et `WITH CHECK`; la politique UPDATE de `agencies` doit vérifier le rôle administrateur dans les deux clauses.
- L'audit SQL renforcé a été exécuté sur le projet Supabase connecté sans erreur. Il s'agit d'une lecture du catalogue : aucune table, donnée, politique ou fonction n'a été modifiée.
- Le validateur CI vérifie maintenant aussi la présence de ces assertions renforcées.
- GitHub Actions run 45062718089 (commit `9f3111f70674397e440eaf720b822a5b8880c29d`) : **SUCCÈS**.
- GitHub Actions run 45062728327 (commit `13ff518b8718fde7ea60418687abfdfe4e928e80`) : **SUCCÈS**. Le dernier commit de la branche de développement est donc validé par le workflow statique.
- Limite inchangée : aucun test réel multi-utilisateur n'a encore vérifié l'isolation entre agences. Le statut `Perdu` n'a pas encore été validé dans un navigateur connecté à Supabase.
- Aucun environnement/branche Supabase supplémentaire n'a été créé. Aucun frais de branche de développement n'a été engagé ; poursuivre sans créer de ressource payante.


## Vérification multi-comptes et sélecteur multi-agences (2026-11-23)

- Test RLS d'exécution réalisé dans une transaction SQL temporaire, avec deux utilisateurs authentifiés existants, deux agences de test, deux prospects et deux activités fictifs.
- Pour chacun des deux utilisateurs, les requêtes sous le rôle `authenticated` et avec `auth.uid()` simulé n'ont retourné que l'agence, l'adhésion, le prospect et l'activité de son périmètre. Le prospect de l'autre agence était invisible (0 ligne).
- Toutes les lignes de test ont été annulées par `ROLLBACK`; aucune donnée persistante n'a été ajoutée ou modifiée.
- L'inspection des adhésions réelles a montré qu'un même compte peut appartenir à plusieurs agences. L'ancienne application ne chargeait qu'une seule adhésion (`limit(1)`) et ne permettait pas de changer d'agence.
- Correctif sur `develop/accelerated`: chargement de toutes les adhésions, affichage d'un sélecteur quand plusieurs agences sont accessibles, mémorisation locale de l'agence choisie par compte et rechargement des prospects à chaque changement. Aucune modification de `main` ni de la base n'a été faite.
- Validateur statique étendu aux contrôles du sélecteur multi-agences.
- GitHub Actions run 45252860767 (commit `ae2bb67c67819512c6ea0135d2564a08061a751a`) : **SUCCÈS**.
- Limites: le test SQL démontre les prédicats RLS sous le rôle `authenticated`, mais ne remplace pas encore le test de parcours complet dans deux sessions navigateur séparées. Le nouveau sélecteur doit aussi être validé en navigateur connecté.

## Prochaines étapes non terminées

1. Parcours navigateur Auth complet avec deux sessions séparées et changement d'agence.
2. Activer la protection des mots de passe compromis via la configuration Auth après vérification des paramètres actuels.
3. Étendre le modèle de données avec biens, mandats, clients/dossiers, documents, tâches, rendez-vous, notifications, équipes/invitations et journal d'audit, avec RLS par agence.
4. Implémenter les écrans et workflows correspondants, puis les tests unitaires et d'intégration.
5. Ajouter l'IA côté serveur avec validation humaine et secrets uniquement côté serveur.
6. Ajouter intégrations de messagerie/calendriers/API, statistiques, plans Essentiel/Agence/Réseau, paiements et administration SaaS.
7. Terminer sauvegarde/restauration, conservation/suppression, export RGPD, audit sécurité, tests charge/mobile et préparation de production.

Aucune de ces étapes n'est considérée comme terminée simplement parce qu'elle figure dans la feuille de route. Les nouveaux modules ne seront pas activés sur la production tant que leurs migrations et politiques d'accès ne seront pas testées en environnement isolé.


## Contrainte du plan Supabase gratuit

- La documentation Supabase consultée le 2026-11-23 indique que la protection Auth contre les mots de passe compromis (HaveIBeenPwned / Leaked Password Protection) est disponible uniquement sur le plan Pro et supérieur.
- Le projet ImmoPilot est maintenu sur le plan gratuit conformément à la contrainte budgétaire de l'utilisateur. Ne pas activer une option payante ni déclencher une mise à niveau sans autorisation explicite.
- L'avertissement Advisor `auth_leaked_password_protection` est donc documenté comme limitation du plan, et non comme une correction réalisable sans frais. Les autres mesures gratuites de sécurité des mots de passe (longueur minimale, règles de robustesse, limitation des tentatives si disponible) restent à auditer dans la configuration Auth.
- Référence officielle: https://supabase.com/docs/guides/auth/password-security


## Durcissement de l'export CSV (2026-11-23)

- L'export CSV neutralise maintenant les valeurs commençant par `=`, `+`, `-` ou `@` (y compris après espaces) en préfixant une apostrophe, afin de limiter l'exécution de formules lors de l'ouverture dans un tableur.
- Le validateur statique vérifie la présence de cette protection et le JavaScript intégré.
- GitHub Actions run 45253233507 (commit `83bec768b8aa0500ef802db7db1b35355d73a0b8`) : **SUCCÈS**.
- La correction est uniquement sur `develop/accelerated`; l'export de la version publiée sur `main` reste inchangé tant que la validation complète n'est pas terminée.


## Agenda mensuel des actions CRM (2026-11-25)

- Ajout sur `develop/accelerated` d'une vue calendrier mensuelle des prochaines actions à partir du champ existant `prospects.next_action_at`.
- Navigation mois précédent/suivant, mise en évidence de la date du jour, repérage des dates hors mois, aperçu de deux prospects par jour et indication du nombre d'actions supplémentaires.
- Un clic sur un prospect ouvre sa fiche CRM existante. Les actions sont filtrées sur l'agence active et les statuts clôturés (Converti/Perdu) ne sont pas affichés comme actions à faire.
- Aucun changement de schéma ni de données Supabase; aucun coût supplémentaire. La vue est alimentée par les prospects déjà chargés et suit le changement d'agence.
- Ajout de contrôles statiques CI pour les éléments du calendrier, la navigation et l'ouverture des fiches.
- GitHub Actions run 45613987658 (commit `6429f96e87fcebe586135da6304e6d18654637be`) : **SUCCÈS** pour la validation HTML/JavaScript du module.
- Le contrôle CI étendu au validateur du calendrier est en cours sur le commit `37ca5d59ef83879dd05abee16bb2df1b49ddc9c9`; attendre son résultat avant de déclarer le lot complètement validé.
- À valider ensuite dans le navigateur sur mobile et ordinateur avec des prospects fictifs ayant des dates variées.


## Revalidation de sécurité (2026-11-25)

- Le script `tests/rls-audit.sql` a été relu depuis la branche de développement puis exécuté sur le projet Supabase connecté. Il s'est terminé sans exception; les assertions catalogue sur les quatre activations RLS, les onze politiques attendues, les contraintes INSERT/UPDATE et les fonctions privées/de création ont passé.
- Aucun schéma, aucune politique et aucune donnée n'ont été modifiés par cet audit (bloc DO de vérification en lecture seule).
- Les Advisors Supabase du 2026-11-25 confirment les deux alertes déjà documentées: fonction `public.create_agency(text)` SECURITY DEFINER nécessaire au parcours d'inscription, et protection des mots de passe compromis non disponible sur le plan gratuit. Deux index créés par les migrations sont signalés inutilisés sur la base de faible volume; ils ne sont pas supprimés sans mesure représentative.


## Lot immobilier — schéma biens et mandats préparé (2026-11-25)

- Nouvelle migration versionnée : `supabase/migrations/202611250001_properties_and_mandates.sql`.
- Table `properties`: référence unique par agence, type de bien, vente/location, adresse, code postal, ville, surface, pièces, prix, statut, description et traçabilité.
- Table `mandates`: lien composite vers un bien de la même agence, type et numéro de mandat uniques par agence, statut, dates, commission et notes.
- Les deux tables ont RLS activé, quatre politiques CRUD par appartenance à l'agence, contrôle du créateur à l'insertion, contraintes de cohérence, index et trigger de mise à jour.
- Le script `tests/rls-audit.sql` et le validateur CI ont été étendus pour contrôler la présence de cette migration et ses politiques.
- Aucun changement n'a été appliqué à Supabase : l'environnement disponible est celui du prototype actif, pas une base de test isolée. Aucune table nouvelle n'est donc encore présente en production.
- Étape restante avant écran applicatif : provisionner un environnement de développement sans frais supplémentaires, y appliquer la migration, exécuter l'audit RLS et des tests multi-agences, puis construire les écrans biens/mandats et les formulaires.


## Préparation environnement Supabase local gratuit (2026-11-25)

- Ajout de `supabase/config.toml` avec projet local isolé `immopilot-local`, ports locaux dédiés et Auth de développement; aucun secret ni identifiant de projet distant.
- Ajout de `tests/local-smoke.sql` pour vérifier les six tables, RLS sur chacune, huit politiques CRUD biens/mandats, la clé étrangère composite mandat/bien/agence et la fonction privée d'appartenance.
- Ajout de `.github/workflows/supabase-local.yml` : lance Supabase CLI v3 sur runner GitHub isolé, applique les migrations via `supabase db reset --local`, puis exécute le smoke test SQL via psql. Le test ne cible pas le projet hébergé.
- Documentation des prérequis et commandes dans `SUPABASE_SETUP.md`. Le lancement local sur le poste utilisateur nécessite Docker et la CLI; impossible de démarrer des conteneurs depuis l'environnement ChatGPT mobile.
- Workflow local CI #45616576476 en cours au moment de cette note; ne pas déclarer la migration validée avant son résultat final.
- Sécurité opérationnelle : ne pas ajouter de `--remote`, ne pas utiliser `db reset --remote`, ne pas relier la base de test à la production.


## Validation de l'environnement Supabase local isolé (2026-11-25)

- GitHub Actions run **45616659660** : **SUCCÈS**. Le job `local-supabase` a terminé toutes ses étapes.
- Supabase CLI v3 a démarré une stack locale jetable sur le runner GitHub; toutes les migrations du dépôt ont été appliquées avec `supabase db reset --local`.
- Le smoke test SQL s'est exécuté avec succès : six tables attendues, RLS sur les six tables, huit politiques CRUD biens/mandats, clé étrangère composite mandat/bien/agence et fonction privée d'appartenance.
- Cela valide la syntaxe et l'application des migrations dans un environnement PostgreSQL/Supabase local isolé. Cela ne prouve pas encore le parcours navigateur complet ni les tests RLS multi-sessions sur les nouveaux modules.
- Le projet Supabase hébergé n'a pas été modifié; aucun abonnement, branche distante ou frais supplémentaires n'a été engagés.
- La prochaine étape est d'implémenter les écrans et opérations CRUD des biens et mandats sur la branche de développement, puis d'ajouter des tests fonctionnels et multi-agences.
- Exécution vérifiable : https://github.com/contacttechagence-beep/Immo-pilot/actions/runs/45616659660
