# dash — Console DOCSIA (dash.montaigne.contact)

Console interne UBM : pilotage récolte + ingestion IA, et (phase 2) stats Metabase.

## Contenu

```
dash/
├── docker-compose.yml   nginx:alpine, 127.0.0.1:8088, réseau docker_default
├── nginx.conf           page statique + /api/ -> proxy interne vers n8n
└── html/index.html      page autonome (thème auto, sans dépendance externe)
```

## Principe

Le navigateur ne parle qu'à `dash.montaigne.contact` (même origine). Les actions
partent en `/api/<nom>` ; nginx les relaie **en interne** vers
`http://n8n:5678/webhook/<nom>` sur le réseau `docker_default`. Aucun webhook n8n
exposé, aucun secret dans le JS, une seule policy Cloudflare Access devant.

Webhooks n8n attendus : `dash-ingestion` (POST), `dash-status` (GET).

## Déploiement serveur

```
git clone https://github.com/protazelbaze/dash.git /opt/stacks/dash
cd /opt/stacks/dash
docker compose up -d
```

Prérequis : réseau docker `docker_default` existant (backend docsia), conteneur
`n8n` joignable, port `8088` libre. Exposition via cloudflared
(`dash.montaigne.contact` -> `127.0.0.1:8088`) + Access « Équipe UBM ».

Mise à jour : `cd /opt/stacks/dash && git pull && docker compose up -d`.
