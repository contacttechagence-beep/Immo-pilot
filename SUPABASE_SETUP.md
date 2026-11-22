# Préparer le backend ImmoPilot (V2)

Ce dépôt est public et héberge le front statique sur GitHub Pages. Le backend n'est **pas encore connecté**. Cette étape ajoute le schéma SQL de départ et les instructions de configuration, sans clé secrète et sans donnée client.

## Architecture retenue pour le prototype V2

- Front : HTML/JavaScript statique, publié par GitHub Pages.
- Backend envisagé : Supabase (PostgreSQL + Auth), avec un projet situé dans l'Union européenne.
- Isolation : chaque ligne métier porte un `agency_id`; les politiques PostgreSQL RLS contrôlent l'appartenance à l'agence.
- Création d'agence : fonction SQL `create_agency()`, qui crée l'agence et son premier membre propriétaire dans une transaction.
- Tables : `agencies`, `agency_members`, `prospects`, `activities`.

## Configuration manuelle requise

1. Créer un compte/projet Supabase depuis le tableau de bord officiel.
2. Choisir une région UE précise, idéalement **Paris (eu-west-3)** ou **Frankfurt (eu-central-1)** selon la latence et les exigences contractuelles.
3. Dans **SQL Editor**, exécuter le fichier `supabase/migrations/202611220001_initial_schema.sql`.
4. Dans **Authentication**, configurer les URL autorisées pour le futur site GitHub Pages et vérifier le parcours de confirmation d'adresse e-mail.
5. Ne pas connecter de vraies agences à cette étape. Le schéma doit d'abord être testé avec deux comptes et deux agences fictives.

## Limites du gratuit

Au 22 novembre 2026, la page tarifaire Supabase indique un plan Free à 0 $, 500 MB de base de données, 50 000 utilisateurs actifs mensuels et une mise en pause possible après une semaine d'inactivité. Le plan gratuit n'inclut pas les sauvegardes automatiques. Il convient à un prototype et à des tests, pas à une promesse de disponibilité pour un SaaS commercial. Vérifier les conditions avant toute mise en production.

## Sécurité — règles non négociables

- Ne jamais mettre de clé `service_role`, mot de passe, jeton privé ou secret dans le dépôt GitHub, le HTML ou le JavaScript.
- Une clé publique Supabase ne pourra être utilisée dans le navigateur qu'après vérification complète des politiques RLS.
- La migration active RLS sur toutes les tables métier et ne donne aucun accès au rôle `anon`.
- Les membres sont créés côté serveur dans un futur flux d'invitation contrôlé. Ne pas ouvrir l'insertion directe dans `agency_members`.
- Tester l'isolation : un compte de l'agence A ne doit jamais lire, modifier ou supprimer les lignes de l'agence B, même en modifiant manuellement les identifiants dans une requête.
- La fonction de création d'agence et les politiques SQL doivent être testées dans un projet de test avant tout usage réel.

## Avant un pilote réel

Il reste à développer et tester : interface de connexion/déconnexion, récupération de mot de passe, liaison du front à Supabase, invitation des collaborateurs, gestion des rôles, validation serveur, limitation des abus, sauvegardes et restauration, journalisation, politique de conservation/suppression, export des données, DPA et analyse RGPD. Le choix d'une région UE ne suffit pas à rendre le traitement conforme.

**Tant que ces étapes ne sont pas terminées, conserver uniquement des données fictives.**
