# ImmoPilot — prototype SaaS

ImmoPilot est un outil en cours de conception pour aider les agences immobilières à structurer les demandes entrantes, qualifier les prospects et suivre les prochaines actions.

## Contenu
- index.html : page de présentation et démonstration interactive de qualification par règles simples.
- app.html : tableau de bord connecté à Supabase Auth et PostgreSQL : création de compte, connexion, récupération de mot de passe, création initiale d'agence, gestion des prospects, export CSV, score indicatif de complétude sur 100 points et priorité de suivi calculée par règles.
- SUPABASE_SETUP.md : configuration, architecture, état des tests et limites.
- supabase/migrations/202611220001_initial_schema.sql : schéma PostgreSQL multi-agences avec RLS.
- supabase/migrations/202611220002_tighten_table_and_function_grants.sql : privilèges SQL minimaux pour le front.
- supabase/migrations/202611220003_index_foreign_keys.sql : index des clés étrangères.

## État actuel
Le tableau de bord a été relié au projet Supabase ImmoPilot (région Paris). Les prospects du tableau de bord sont désormais lus et enregistrés dans PostgreSQL, et non plus dans le stockage local de démonstration. La connexion utilise une clé publishable, jamais une clé privilégiée.

Le parcours Auth nécessite que les URL du site soient configurées dans Supabase → Authentication → URL Configuration. Voir SUPABASE_SETUP.md.

Ce dépôt public et le backend restent un prototype. L'isolation entre deux agences n'a pas encore été validée par des tests de bout en bout. Un avertissement Supabase concerne la fonction create_agency() en SECURITY DEFINER ; des index de clés étrangères restent à optimiser.

## Publication
Le site est publié via GitHub Pages. Le tableau de bord se trouve dans app.html.

## Sécurité
Ne jamais ajouter de clé service_role, de clé secrète, de mot de passe, de jeton privé ou de données personnelles à ce dépôt public. Les clés publishable sont destinées au navigateur, à condition que les politiques RLS soient correctes.

**Ne pas utiliser avec de vrais prospects clients tant que les tests d'isolation, l'audit de sécurité et la validation RGPD ne sont pas terminés.** Toute future intégration IA devra passer par un serveur et une variable d'environnement secrète.
