# ImmoPilot — configuration Supabase et état du prototype

Le projet Supabase ImmoPilot existe dans la région Paris (eu-west-3). Le tableau de bord web utilise maintenant Supabase Auth et PostgreSQL. Il s'agit d'un prototype de validation, pas d'un service prêt pour les données réelles.

## Architecture installée

- Front statique : GitHub Pages, fichier app.html.
- Backend : Supabase Auth + PostgreSQL.
- Projet Supabase : zzcvvvfnkjhdhrwqbfgm.
- URL API : https://zzcvvvfnkjhdhrwqbfgm.supabase.co.
- Tables : agencies, agency_members, prospects, activities.
- Isolation par agence : RLS et colonne agency_id.
- Authentification : création de compte par e-mail, confirmation d'adresse, connexion, déconnexion et récupération de mot de passe.
- Les prospects créés depuis le tableau de bord sont enregistrés dans PostgreSQL et chargés depuis l'agence de l'utilisateur connecté.

Le navigateur utilise une clé publishable Supabase. Elle est conçue pour être publique et ne doit jamais être confondue avec une clé service_role ou une clé secret. Aucune clé privilégiée, aucun mot de passe de base de données et aucun jeton privé ne doivent être placés dans le dépôt.

## Action manuelle indispensable — URL Auth

Avant de tester l'inscription, ouvrir le projet Supabase puis Authentication → URL Configuration :

1. Régler Site URL sur :
   https://contacttechagence-beep.github.io/Immo-pilot/app.html
2. Ajouter exactement cette même adresse dans Redirect URLs.
3. Enregistrer. Conserver la confirmation d'adresse e-mail activée.
4. Vérifier que les e-mails de confirmation et de réinitialisation redirigent bien vers l'application.

La configuration de redirection est nécessaire pour les confirmations et les réinitialisations. Documentation officielle : https://supabase.com/docs/guides/auth/redirect-urls

## Parcours utilisateur actuellement codé

1. L'utilisateur crée un compte avec e-mail et mot de passe.
2. Si la confirmation e-mail est activée, il clique sur le lien reçu puis revient à l'application pour se connecter.
3. À la première connexion, l'application lui demande le nom de son agence et appelle create_agency().
4. L'application charge les prospects associés à son agence.
5. Les opérations d'ajout, modification, suppression et export CSV utilisent les données Supabase.

La récupération de mot de passe envoie un lien ; le formulaire de nouveau mot de passe s'affiche à l'ouverture du lien de récupération.

## Migrations

- supabase/migrations/202611220001_initial_schema.sql : schéma multi-agences et politiques RLS.
- supabase/migrations/202611220002_tighten_table_and_function_grants.sql : réduction des privilèges SQL par défaut.
- supabase/migrations/202611220003_index_foreign_keys.sql : index complémentaires sur les clés étrangères.

Ces migrations ont été appliquées au projet. La deuxième migration a aussi été ajoutée au dépôt pour conserver une trace versionnée des permissions.

## Vérifications et limites connues

- Les quatre tables existent et RLS est activé.
- Le rôle anon n'a pas de droits directs sur les tables métier.
- Le rôle authenticated a uniquement les droits de table prévus pour le prototype.
- L'Advisor Supabase signale un avertissement sur public.create_agency(text), une fonction SECURITY DEFINER volontairement exécutable par les utilisateurs connectés pour créer leur première agence. Cette fonction vérifie auth.uid() et utilise un search_path vide, mais elle doit faire l'objet d'une revue de sécurité avant lancement.
- Les trois clés étrangères initialement signalées ont reçu des index complémentaires. Les Advisors marquent maintenant certains index comme inutilisés, ce qui est attendu sur une base de test encore vide ; il faudra réévaluer après chargement de données fictives.
- L'isolation réelle entre deux comptes et deux agences n'a pas encore été démontrée par un test de bout en bout.
- L'envoi d'invitations, la gestion des rôles et l'administration des membres ne sont pas implémentés.
- Les limites et tarifs Supabase peuvent évoluer ; vérifier les conditions en vigueur avant un usage commercial.

## Protection des mots de passe compromis

Supabase documente la protection contre les mots de passe compromis (HaveIBeenPwned) comme une fonctionnalité réservée au plan Pro et supérieur. Le projet restant sur le plan gratuit, cette option n'est pas activée et aucune mise à niveau payante ne sera déclenchée. Voir la documentation officielle: https://supabase.com/docs/guides/auth/password-security.

## Multi-agences et isolation vérifiée

L'application sur la branche `develop/accelerated` charge désormais toutes les adhésions de l'utilisateur et permet de sélectionner l'agence active. Le choix est mémorisé localement pour chaque compte. La branche `main` publiée n'est pas encore modifiée.

Un test SQL temporaire a été exécuté avec deux utilisateurs et deux agences fictives dans une transaction terminée par `ROLLBACK`. Sous le rôle `authenticated`, chaque utilisateur ne voyait que l'agence, le prospect et l'activité associés à son adhésion; l'enregistrement de l'autre agence était invisible. Ce test de politiques RLS ne remplace pas le test complet dans deux navigateurs et deux sessions Auth distinctes.

## Avant un pilote réel

Il faut encore réaliser un test avec au moins deux comptes et deux agences fictives, contrôler les accès inter-agences, auditer la fonction de création d'agence et les politiques RLS, traiter les index signalés, configurer les sauvegardes et la restauration, les journaux, les règles de conservation/suppression, les conditions contractuelles et le RGPD. Le choix d'une région UE ne suffit pas à établir la conformité.

**Ne pas saisir de données personnelles réelles ou de prospects clients avant la fin de ces contrôles.**
