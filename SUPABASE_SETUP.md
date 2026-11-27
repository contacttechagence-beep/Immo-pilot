# ImmoPilot — configuration et état technique

État vérifié le 27 novembre 2026. Ce document décrit le prototype en place et les contrôles réellement effectués ; il ne constitue pas une validation de mise en production.

## Architecture installée

- Front statique : GitHub Pages, `app.html`.
- Backend : Supabase Auth + PostgreSQL 17.
- Projet : `zzcvvvfnkjhdhrwqbfgm`, région `eu-west-3` (Paris), état vérifié : `ACTIVE_HEALTHY`.
- Tables : `agencies`, `agency_members`, `agency_invitations`, `audit_logs`, `prospects`, `activities`, `contacts`, `properties`, `mandates`, `tasks`, `documents`, `appointments`.
- Toutes les tables métier exposées ont RLS activé, avec des politiques adaptées à l'appartenance à l'agence.
- Les politiques métier utilisent les fonctions `private.is_agency_member` et `private.is_agency_admin` pour contrôler l'appartenance à l'agence.
- Auth : inscription, confirmation par e-mail, connexion, déconnexion et récupération de mot de passe.
- Le front utilise une clé publishable. Ne jamais placer de clé secrète ou `service_role` dans le navigateur ou dans ce dépôt public.

## Fonctionnalités présentes

- Sélection de l'agence active parmi les agences auxquelles le compte appartient.
- Gestion des prospects (ajout, lecture, modification, suppression, recherche, filtre et export CSV).
- Score de qualification indicatif, priorités et conseil commercial.
- Historique des appels, e-mails, rendez-vous, notes et changements de statut.
- Rappels des actions en retard, du jour, à venir ou à planifier.
- Documents privés : dépôt, rattachement à un prospect/contact/bien/mandat, liste, téléchargement et suppression.
- Agenda : calendrier mensuel, rendez-vous/visites/appels/réunions/signatures, horaires, lieux, statuts et rattachement au CRM.

## URL Auth à contrôler dans Supabase

Dans Authentication → URL Configuration :
- Site URL : `https://contacttechagence-beep.github.io/Immo-pilot/app.html`
- Ajouter la même adresse dans Redirect URLs.
- Garder la confirmation d'adresse e-mail activée.
- Vérifier les liens de confirmation et de récupération.

## Migrations installées

1. `202611220001_initial_schema.sql`
2. `202611220002_tighten_table_and_function_grants.sql`
3. `202611220003_index_foreign_keys.sql`
4. `20261126144634_crm_contacts_properties_mandates_tasks.sql`
5. `20261126144651_crm_fk_indexes_and_member_assignment.sql`
6. `20261126144822_tasks_assignee_fk_index.sql`
7. `20261126145057_crm_private_document_management.sql`
8. `20261126145214_documents_uploaded_by_index.sql`
9. `20261126145249_documents_permissions_hardening.sql`
10. `20261126152712_crm_calendar_appointments.sql`
11. `20261126152833_appointments_created_by_index.sql`
12. `20261126180809_team_member_management.sql`
13. `20261126180827_team_member_authz_hardening.sql`
14. `20261126181152_team_member_rls_mutations.sql`
15. `20261126181605_team_assignment_roster.sql`
16. `20261126193332_agency_invitation_links.sql`
17. `20261126193623_agency_invitation_direct_access_denied.sql`
18. `20261126193930_agency_audit_trail.sql`
19. `20261126194117_agency_audit_read_only_permissions.sql`

Les 19 migrations listées ci-dessus sont présentes dans le dépôt. La cohérence entre le dépôt et l’historique Supabase doit être contrôlée après chaque migration.

## Audit complémentaire effectué le 27 novembre 2026

### RLS et fonction de création d'agence

Les 12 tables du schéma `public` ont RLS activé et disposent toutes d’au moins une politique. Les politiques SELECT/INSERT/UPDATE/DELETE des tables prospects et activités contrôlent l'appartenance à l'agence. Les rôles et privilèges ont été inspectés.

La fonction `public.create_agency(text)` est `SECURITY DEFINER` car elle doit créer une agence et sa première adhésion sans donner au navigateur des privilèges directs supplémentaires. Elle vérifie `auth.uid()`, valide le nom et définit un `search_path` vide. Vérification effective : `anon` et `PUBLIC` ne peuvent pas l'exécuter ; `authenticated` dispose du droit d'exécution. La fonction valide l’identité et le nom de l’agence. L'avertissement Advisor sur une fonction SECURITY DEFINER accessible aux utilisateurs connectés demeure attendu pour ce flux ; la fonction doit néanmoins rester limitée à cette opération et être revue avant lancement.

### Points à traiter avant pilote réel

- Supabase Advisor indique que la protection contre les mots de passe compromis (HaveIBeenPwned) est désactivée. L'activer dans les réglages Auth du tableau de bord Supabase.
- Deux index de clés étrangères sont actuellement signalés comme inutilisés. Ils sont conservés ; réévaluer leur utilité après des essais avec un volume représentatif, sans les supprimer à l'aveugle.
- Effectuer un test complet avec deux comptes et deux agences fictives : accès autorisés, absence de fuite croisée, changement d'agence, création/modification/suppression et historique.
- Vérifier qu'un utilisateur ne peut pas réaffecter un enregistrement à une autre agence en manipulant les requêtes.
- Finaliser les sauvegardes, la restauration, les journaux, les règles de conservation et suppression, les procédures de sécurité et l'analyse RGPD.
- La région UE ne suffit pas à démontrer la conformité RGPD.

## Résultats des tests de la phase du 26 novembre 2026

- JavaScript de l'application : analyse syntaxique réussie.
- Création transactionnelle sous le rôle `authenticated` : contact, bien, mandat et tâche créés avec succès puis annulés ; aucune donnée fictive de test n'a été conservée.
- Test de séparation entre deux utilisateurs appartenant à des agences distinctes : le second compte a vu `0` ligne du contact créé dans l'agence du premier compte.
- Contrôle des quatre nouvelles tables : RLS activé ; privilèges `authenticated` présents ; aucun droit SELECT accordé à `anon`.
- Advisor santé : aucun avertissement. Advisor performance : aucune clé étrangère non indexée ; les index inutilisés restent attendus tant que la base contient peu de données.
- L’Advisor sécurité signale les RPC `SECURITY DEFINER` accessibles à `authenticated` (`create_agency`, lecture des membres et opérations d’invitation). Ces fonctions sont volontairement exposées pour réaliser des opérations atomiques, vérifient l’identité/le rôle/l’agence, utilisent un `search_path` vide et refusent `anon` ; elles doivent rester auditées. La protection contre les mots de passe compromis (HaveIBeenPwned) reste désactivée et doit être activée dans les réglages Auth du tableau de bord Supabase. L’activation n’a pas été effectuée par SQL.

## Modules développés dans la phase du 26 novembre 2026

- `contacts` : répertoire CRM avec typologie et coordonnées ; liaison facultative d'un prospect à un contact.
- `properties` : portefeuille des biens, références uniques par agence, localisation, caractéristiques, prix et statut.
- `mandates` : mandat lié à un bien et à un propriétaire de la même agence, type, dates, honoraires et statut.
- `tasks` : tâches datées et priorisées, rattachées à un prospect, un contact ou un bien ; l'affectation est limitée à un membre de l'agence.
- Les tables CRM ajoutées ont RLS activé, des politiques membres d'agence et des privilèges Data API explicites. Les clés étrangères entre entités incluent l'agence pour empêcher les liens inter-agences.

## Agenda — module développé le 26 novembre 2026

- Table `appointments` : rendez-vous, visites, appels, réunions, états des lieux et signatures ; début/fin, lieu, statut, description, responsable.
- Calendrier mensuel interactif : navigation mois précédent/suivant, retour à aujourd'hui, sélection d'un jour et affichage du programme du jour.
- Formulaire de création/modification et suppression ; horaires locaux convertis en timestamps avec fuseau (`timestamptz`).
- RLS agence et contrôle que le responsable appartient à la même agence ; les liens prospect/contact/bien sont protégés contre les références inter-agences.
- Tests de structure et de privilèges réussis ; `authenticated` autorisé, `anon` refusé. Aucun rendez-vous de test conservé.

## Documents — module développé le 26 novembre 2026

- Bucket `immopilot-documents` privé (jamais public), limite de 20 Mo par fichier et types MIME restreints.
- Table `documents` avec RLS et droits Data API explicites ; chaque document est lié à son agence et peut être rattaché à un prospect, contact, bien ou mandat de la même agence.
- Storage RLS : seuls les membres de l'agence peuvent déposer, lire/télécharger et supprimer les fichiers dont le chemin commence par leur `agency_id`.
- Interface `app.html` : formulaire de dépôt, classement facultatif, liste, téléchargement authentifié et suppression.
- Test SQL temporaire : un membre voit son document, un utilisateur d'une autre agence voit zéro ligne ; transaction annulée.
- Vérification des droits : `authenticated` autorisé, `anon` explicitement révoqué.
- Le transfert réel d'un fichier via navigateur et l'isolation Storage doivent encore être testés avec un fichier fictif ; aucun document de client réel ne doit être utilisé.

## Modules restant à développer

IA côté serveur, intégrations, statistiques et tableaux de bord avancés, administration SaaS et facturation, sécurité renforcée.

Aucune fonctionnalité prévue ne doit être supprimée pour accélérer le développement. Les essais utilisent exclusivement des données fictives. Aucun test utilisateur supplémentaire ne sera demandé avant que la phase de développement prévue soit terminée.

## Équipe — administration des membres

- `list_agency_members(uuid)` : réservée aux propriétaires et administrateurs, retourne l’identifiant, l’e-mail, le rôle et la date d’adhésion.
- `update_agency_member_role(uuid, uuid, text)` : le propriétaire peut attribuer `admin` ou `agent` à un autre membre ; le rôle `owner` est protégé.
- `remove_agency_member(uuid, uuid)` : propriétaire peut retirer admin/agent ; administrateur peut retirer agent ; auto-retrait et retrait du propriétaire interdits.
- Fonctions `SECURITY DEFINER`, `search_path` vide, exécution révoquée à `PUBLIC` et `anon`, accordée uniquement à `authenticated` ; contrôle du rôle effectué dans la fonction.
- La liste et les actions sont exposées dans l’onglet Équipe pour les comptes propriétaire/administrateur.
- Les invitations par e-mail automatique ne sont pas activées. Les liens d’invitation sécurisés sont créés dans l’application et doivent être partagés manuellement ; aucun fournisseur d’envoi n’est requis.

## Application

https://contacttechagence-beep.github.io/Immo-pilot/app.html


## Invitations d’équipe — liens sécurisés

Migration appliquée : `20261126193332_agency_invitation_links.sql`.

- Table `agency_invitations` avec RLS activé, une politique explicite de refus total et aucun privilège direct accordé à `anon` ou `authenticated`.
- Le jeton aléatoire de 256 bits est généré côté PostgreSQL ; seul son condensat SHA-256 est conservé en base.
- `create_agency_invitation(uuid,text,text)` : propriétaire peut inviter administrateur ou agent ; administrateur peut inviter agent uniquement.
- `list_agency_invitations(uuid)` : affiche les invitations en attente aux responsables autorisés.
- `revoke_agency_invitation(uuid,uuid)` : invalide immédiatement un lien non utilisé.
- `accept_agency_invitation(text)` : accepte une seule fois, avant expiration, uniquement si l’utilisateur connecté a confirmé exactement l’adresse e-mail invitée.
- Les liens expirent après 7 jours. Les invitations précédentes pour la même adresse sont révoquées lors de la création d’un nouveau lien.
- L’interface permet de créer, copier et révoquer les liens. Aucun e-mail automatique n’est envoyé ; le partage s’effectue avec la messagerie habituelle.
- La page d’authentification conserve le paramètre d’invitation pendant la création du compte et traite le jeton après authentification.

Les tests de flux réel avec deux comptes distincts et la validation visuelle navigateur restent à effectuer avant de déclarer le module prêt à l’usage.


## Journal d’audit — traçabilité des opérations

Migration appliquée : `20261126193930_agency_audit_trail.sql`.

- Table `audit_logs` avec RLS ; lecture réservée aux propriétaires et administrateurs de l’agence ; privilège SELECT uniquement pour `authenticated`, aucune écriture directe.
- Triggers sur prospects, historique CRM, contacts, biens, mandats, tâches, rendez-vous et documents.
- Enregistre les créations, modifications et suppressions, l’identifiant du membre, le type d’objet et les noms des champs concernés.
- Ne conserve jamais les valeurs précédentes ou nouvelles des champs, afin de limiter l’exposition de données personnelles.
- Pas d’écriture directe depuis le navigateur ; la fonction de trigger privée réalise l’insertion.
- Test transactionnel effectué sur un contact fictif : insertion, modification (champ `phone` identifié) et suppression ont généré trois événements ; transaction annulée, aucune donnée de test conservée.
- Interface Journal réservée aux propriétaires et administrateurs, avec filtres par module et type d’action ; les 100 derniers événements sont affichés.
