# ImmoPilot — prototype SaaS

ImmoPilot est un logiciel en cours de développement pour les agences immobilières : gestion des prospects, qualification, priorisation, historique des échanges et suivi des prochaines actions.

## Application et architecture actuelles

- Site public et démonstration : `index.html`.
- Espace connecté : `app.html`, publié via GitHub Pages.
- Backend : Supabase Auth + PostgreSQL, projet ImmoPilot en région UE (Paris, `eu-west-3`).
- Tables métier : `agencies`, `agency_members`, `prospects`, `activities`, `contacts`, `properties`, `mandates`, `tasks`, `documents`, `appointments`.
- Authentification : inscription, connexion, déconnexion et récupération de mot de passe.
- Gestion des agences : appartenance multi-agences et sélection de l'agence active.
- Prospects : création, consultation, modification, suppression, recherche, filtres et export CSV.
- Qualification et priorité : score indicatif sur 100, informations manquantes et recommandations commerciales basées sur des règles.
- Historique : appels, e-mails, rendez-vous, notes et changements de statut.
- Rappels : prochaines actions, retards et échéances.
- Documents : stockage privé Supabase, classement par agence, rattachement facultatif à un prospect, contact, bien ou mandat, téléchargement et suppression ; formats PDF/Office/images/CSV/TXT, limite applicative de 20 Mo.
- Agenda : calendrier mensuel, rendez-vous, visites, appels, réunions, signatures et états des lieux ; gestion des horaires, lieux, statuts et rattachement aux prospects, contacts et biens.
- Le navigateur utilise une clé publishable. Aucune clé `service_role` ou clé secrète ne doit être exposée dans le dépôt.

## Contrôles techniques effectués le 25 novembre 2026

- Projet Supabase : état `ACTIVE_HEALTHY`, PostgreSQL 17.
- À la date du contrôle initial, les tables métier de base avaient toutes RLS activé ; les modules CRM, documents et agenda ajoutés ensuite disposent également de RLS.
- Onze migrations sont présentes dans la base et dans le dépôt.
- Les politiques RLS limitent les lectures et écritures aux membres de l'agence concernée.
- La fonction `public.create_agency(text)` est une fonction `SECURITY DEFINER` nécessaire à la création initiale d'une agence. Elle vérifie la session authentifiée et utilise un `search_path` vide. Vérification des privilèges : exécution refusée à `anon` et à `PUBLIC`, autorisée à `authenticated`. L'avertissement Advisor concernant l'exécution par les utilisateurs connectés est donc à traiter comme une fonction privilégiée volontaire, à surveiller et à auditer, pas comme une permission anonyme.
- L'Advisor signale que la protection contre les mots de passe compromis est désactivée : ce réglage doit être activé dans Supabase Auth avant un pilote réel.
- Deux index sont signalés « inutilisés ». C'est cohérent avec une base de test de faible volume ; ne pas les supprimer sans mesure sur des données de test représentatives.
- Les contrôles SQL de structure et de privilèges ne remplacent pas un test de bout en bout avec deux comptes distincts et des agences distinctes.

## Vérifications de la nouvelle phase — 26 novembre 2026

- Syntaxe JavaScript de l'application vérifiée.
- Test transactionnel sous rôle `authenticated` : création d'un contact, d'un bien, d'un mandat et d'une tâche réussie ; transaction annulée ensuite, aucune donnée de test conservée.
- Test d'isolation entre deux utilisateurs appartenant à des agences distinctes : le second utilisateur ne voit aucune ligne du contact de test (`0` ligne visible).
- Les quatre nouvelles tables ont RLS activé ; `authenticated` dispose des privilèges attendus et `anon` n'a pas de droit SELECT.
- Advisor : aucun problème de santé et aucune clé étrangère non indexée signalée. Les index marqués inutilisés sont normaux sur une base de faible volume.
- Deux avertissements de sécurité préexistants restent à traiter : la fonction de création d'agence `SECURITY DEFINER` volontairement exécutable par les comptes connectés, et la protection contre les mots de passe compromis désactivée.

## Agenda — phase du 26 novembre 2026

- Table `appointments` avec dates/horaires en `timestamptz`, types d'événement, statut, lieu, description, responsable et liens CRM facultatifs.
- Calendrier mensuel avec navigation entre les mois, retour à aujourd'hui et programme du jour sélectionné.
- Création, modification et suppression des rendez-vous ; validation de l'ordre chronologique des horaires.
- RLS agence, contrôle du responsable comme membre de la même agence, clés étrangères composites pour les liens CRM et index des clés étrangères.
- Vérifications SQL : table créée, RLS activé, privilèges `authenticated` présents et accès `anon` refusé. Le test transactionnel d'isolation ne conserve aucune ligne de test.

## Documents — phase du 26 novembre 2026

- Table `documents` avec RLS, contrôle d'appartenance à l'agence et clés étrangères composites empêchant les rattachements inter-agences.
- Bucket `immopilot-documents` privé, taille maximale configurée à 20 Mo et liste MIME autorisée.
- Politiques Storage `SELECT`, `INSERT` et `DELETE` basées sur le premier dossier du chemin (`agency_id`) et l'appartenance au même espace agence.
- L'interface permet le dépôt, le classement, le téléchargement et la suppression. Aucun lien public n'est généré.
- Test transactionnel RLS simulé avec deux comptes : le membre de l'agence voit la fiche documentaire temporaire ; le compte d'une autre agence ne la voit pas. La transaction est annulée, aucune fiche de test n'est conservée.
- Vérification des privilèges : `authenticated` peut accéder à la table, `anon` n'a aucun droit SELECT.
- La validation de bout en bout d'un véritable transfert de fichier via navigateur et Storage avec deux comptes reste à effectuer.

## Limites — ne pas utiliser avec de vrais prospects

ImmoPilot reste un prototype. Les modules équipes/invitations et rôles fins, IA sécurisée, intégrations, statistiques avancées, facturation SaaS et administration restent à développer. La conformité RGPD, la conservation et suppression des données, les sauvegardes/restaurations, la supervision et les procédures d'incident doivent être finalisées avant toute exploitation commerciale.

**Utiliser uniquement des comptes et données fictifs pour les essais. Ne pas importer de données de vrais clients avant validation de la sécurité et du cadre RGPD.**

## Publication

Application : https://contacttechagence-beep.github.io/Immo-pilot/app.html

Dépôt : https://github.com/contacttechagence-beep/Immo-pilot
