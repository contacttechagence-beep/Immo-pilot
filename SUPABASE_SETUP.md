# ImmoPilot — configuration et état technique

État vérifié le 25 novembre 2026. Ce document décrit le prototype en place et les contrôles réellement effectués ; il ne constitue pas une validation de mise en production.

## Architecture installée

- Front statique : GitHub Pages, `app.html`.
- Backend : Supabase Auth + PostgreSQL 17.
- Projet : `zzcvvvfnkjhdhrwqbfgm`, région `eu-west-3` (Paris), état vérifié : `ACTIVE_HEALTHY`.
- Tables : `agencies`, `agency_members`, `prospects`, `activities`.
- Les quatre tables ont RLS activé.
- Les politiques métier utilisent les fonctions `private.is_agency_member` et `private.is_agency_admin` pour contrôler l'appartenance à l'agence.
- Auth : inscription, confirmation par e-mail, connexion, déconnexion et récupération de mot de passe.
- Le front utilise une clé publishable. Ne jamais placer de clé secrète ou `service_role` dans le navigateur ou dans ce dépôt public.

## Fonctionnalités présentes

- Sélection de l'agence active parmi les agences auxquelles le compte appartient.
- Gestion des prospects (ajout, lecture, modification, suppression, recherche, filtre et export CSV).
- Score de qualification indicatif, priorités et conseil commercial.
- Historique des appels, e-mails, rendez-vous, notes et changements de statut.
- Rappels des actions en retard, du jour, à venir ou à planifier.

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

La base indique bien ces trois migrations comme appliquées.

## Audit effectué le 25 novembre 2026

### RLS et fonction de création d'agence

Les quatre tables publiques ont RLS activé. Les politiques SELECT/INSERT/UPDATE/DELETE des tables prospects et activités contrôlent l'appartenance à l'agence. Les rôles et privilèges ont été inspectés.

La fonction `public.create_agency(text)` est `SECURITY DEFINER` car elle doit créer une agence et sa première adhésion sans donner au navigateur des privilèges directs supplémentaires. Elle vérifie `auth.uid()`, valide le nom et définit un `search_path` vide. Vérification effective : `anon` ne peut pas l'exécuter, `PUBLIC` ne peut pas l'exécuter, seul `authenticated` en a le droit. L'avertissement Advisor sur une fonction SECURITY DEFINER accessible aux utilisateurs connectés demeure attendu pour ce flux ; la fonction doit néanmoins rester limitée à cette opération et être revue avant lancement.

### Points à traiter avant pilote réel

- Supabase Advisor indique que la protection contre les mots de passe compromis (HaveIBeenPwned) est désactivée. L'activer dans les réglages Auth du tableau de bord Supabase.
- Deux index de clés étrangères sont actuellement signalés comme inutilisés. Ils sont conservés ; réévaluer leur utilité après des essais avec un volume représentatif, sans les supprimer à l'aveugle.
- Effectuer un test complet avec deux comptes et deux agences fictives : accès autorisés, absence de fuite croisée, changement d'agence, création/modification/suppression et historique.
- Vérifier qu'un utilisateur ne peut pas réaffecter un enregistrement à une autre agence en manipulant les requêtes.
- Finaliser les sauvegardes, la restauration, les journaux, les règles de conservation et suppression, les procédures de sécurité et l'analyse RGPD.
- La région UE ne suffit pas à démontrer la conformité RGPD.

## Modules restant à développer

CRM avancé et contacts, biens/mandats/transactions, documents et stockage, tâches et agenda, équipes/invitations/rôles, IA côté serveur, intégrations, statistiques et tableaux de bord, administration SaaS et facturation, journal d'audit et sécurité renforcée.

Aucune fonctionnalité prévue ne doit être supprimée pour accélérer le développement. Les essais utilisent exclusivement des données fictives. Aucun test utilisateur supplémentaire ne sera demandé avant que la phase de développement prévue soit terminée.

## Application

https://contacttechagence-beep.github.io/Immo-pilot/app.html
