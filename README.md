# ImmoPilot — démonstration commerciale

Ce dépôt contient le prototype statique d'ImmoPilot, un outil en cours de conception pour aider les agences immobilières à structurer les demandes entrantes.

## Contenu
- `index.html` : page de présentation et démonstration interactive.
- `app.html` : tableau de bord de démonstration avec gestion locale des prospects (ajout, consultation, modification, suppression, recherche, filtre et export CSV).
- `SUPABASE_SETUP.md` : architecture V2 envisagée, procédure de configuration et limites de sécurité.
- `supabase/migrations/202611220001_initial_schema.sql` : schéma PostgreSQL multi-agences avec politiques RLS.

## État actuel
Le site public reste une démonstration locale côté navigateur. La qualification repose sur des règles simples intégrées au JavaScript. Il ne comporte **pas encore de connexion à une base distante, d'authentification, d'envoi de messages ou d'intégration CRM**. La migration SQL V2 est un socle à installer et tester dans un projet Supabase séparé ; elle n'est pas exécutée automatiquement et aucun projet Supabase n'est connecté.

## Tester
Ouvrir `index.html` dans un navigateur récent. Utiliser uniquement les données fictives prévues pour la démonstration. Ne pas saisir de données personnelles réelles.

## Publication GitHub Pages
Dans le dépôt GitHub : **Settings → Pages → Build and deployment → GitHub Actions**. Après le déploiement, l'URL publique est disponible dans les paramètres Pages.

## Avant tout pilote avec une agence
La migration V2 doit être testée avec au moins deux comptes et deux agences fictives pour vérifier l'isolation RLS. Il reste à développer l'interface de connexion, le parcours d'invitation, la liaison du front au backend, les sauvegardes/restaurations, les contrôles d'abus, l'export/suppression et le cadrage RGPD/contractuel. Le choix d'une région UE ne suffit pas à établir la conformité.

Ne jamais publier une clé API, une clé Supabase `service_role`, un mot de passe ou un autre secret dans ce dépôt public. Une clé publique ne pourra être utilisée dans le navigateur qu'après validation des politiques RLS. Toute future intégration OpenAI devra passer par un serveur et une variable d'environnement secrète.

Les scores de démonstration sont indicatifs et ne doivent pas servir à accepter ou refuser un client. Les informations et réponses doivent être vérifiées par un humain.
