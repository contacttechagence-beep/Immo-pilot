# ImmoPilot — prototype SaaS

ImmoPilot est un logiciel en cours de développement pour les agences immobilières : gestion des prospects, qualification, priorisation, historique des échanges et suivi des prochaines actions.

## Application et architecture actuelles

- Site public et démonstration : `index.html`.
- Espace connecté : `app.html`, publié via GitHub Pages.
- Backend : Supabase Auth + PostgreSQL, projet ImmoPilot en région UE (Paris, `eu-west-3`).
- Tables métier : `agencies`, `agency_members`, `prospects`, `activities`.
- Authentification : inscription, connexion, déconnexion et récupération de mot de passe.
- Gestion des agences : appartenance multi-agences et sélection de l'agence active.
- Prospects : création, consultation, modification, suppression, recherche, filtres et export CSV.
- Qualification et priorité : score indicatif sur 100, informations manquantes et recommandations commerciales basées sur des règles.
- Historique : appels, e-mails, rendez-vous, notes et changements de statut.
- Rappels : prochaines actions, retards et échéances.
- Le navigateur utilise une clé publishable. Aucune clé `service_role` ou clé secrète ne doit être exposée dans le dépôt.

## Contrôles techniques effectués le 25 novembre 2026

- Projet Supabase : état `ACTIVE_HEALTHY`, PostgreSQL 17.
- Les quatre tables métier existent et ont toutes RLS activé.
- Trois migrations sont présentes dans la base et dans le dépôt.
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

## Limites — ne pas utiliser avec de vrais prospects

ImmoPilot reste un prototype. Les modules documents, agenda avancé, équipes/invitations et rôles fins, IA sécurisée, intégrations, statistiques avancées, facturation SaaS et administration restent à développer. La conformité RGPD, la conservation et suppression des données, les sauvegardes/restaurations, la supervision et les procédures d'incident doivent être finalisées avant toute exploitation commerciale.

**Utiliser uniquement des comptes et données fictifs pour les essais. Ne pas importer de données de vrais clients avant validation de la sécurité et du cadre RGPD.**

## Publication

Application : https://contacttechagence-beep.github.io/Immo-pilot/app.html

Dépôt : https://github.com/contacttechagence-beep/Immo-pilot
