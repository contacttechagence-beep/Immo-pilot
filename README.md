# ImmoPilot — démonstration commerciale

Ce dépôt contient le prototype statique d'ImmoPilot, un outil en cours de conception pour aider les agences immobilières à structurer les demandes entrantes.

## Contenu
- `index.html` : page de présentation et démonstration interactive.

## État actuel
Cette version est une démonstration locale côté navigateur. La qualification repose sur des règles simples intégrées au JavaScript. Elle ne comporte **ni intelligence artificielle connectée, ni base de données, ni authentification, ni envoi de messages, ni intégration CRM**.

## Tester
Ouvrir `index.html` dans un navigateur récent. Utiliser uniquement les données fictives prévues pour la démonstration. Ne pas saisir de données personnelles réelles.

## Publication GitHub Pages
Dans le dépôt GitHub : **Settings → Pages → Build and deployment → Deploy from a branch**. Choisir la branche `main`, le dossier `/(root)`, puis enregistrer. Après le déploiement, GitHub affichera l'URL publique dans cette page.

## Avant tout pilote avec une agence
Prévoir notamment l'authentification et les rôles, le stockage sécurisé, les sauvegardes, la gestion des accès, la confidentialité, l'analyse RGPD, les conditions contractuelles applicables, la limitation des abus et des tests de sécurité. Ne jamais publier une clé API dans ce dépôt. Toute future intégration OpenAI devra passer par un serveur et une variable d'environnement secrète.

Les scores de démonstration sont indicatifs et ne doivent pas servir à accepter ou refuser un client. Les informations et réponses doivent être vérifiées par un humain.
