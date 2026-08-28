# dash — Console DOCSIA (dash.montaigne.contact)

Console interne UBM : pilotage récolte + ingestion IA, journal d'opérations, et
(phase 2) stats Metabase.

## Contenu

```
dash/
├── docker-compose.yml   nginx (page + proxy) + postgrest (lecteur du journal)
├── nginx.conf           statique + /api/ -> n8n, /api/log -> postgrest
├── html/index.html      page autonome (thème auto, sans dépendance externe)
├── ops_log.sql          table ops_log + vue api.ops_log + rôles (à jouer sur ubm_postgres)
├── .env.example         PGRST_AUTH_PASSWORD (copier en .env)
└── .gitignore
```

## Principe

Le navigateur ne parle qu'à `dash.montaigne.contact` (même origine). nginx relaie
en interne :

- `/api/<nom>`  -> `http://n8n:5678/webhook/<nom>` (actions ; webhooks n8n).
- `/api/log`    -> PostgREST -> vue `api.ops_log` (journal, lecture seule).

Aucun webhook n8n ni base exposés au navigateur, aucun secret dans le JS, une
seule policy Cloudflare Access devant.

## Journal central (ops_log)

Magasin neutre dans `ubm_postgres` (base `ubm_datas`), lisible par PostgREST et
par Metabase. N'importe quel producteur y écrit sa ligne (n8n via un nœud Postgres
rôle `ops_writer` ; plus tard Paperless, docsia, récolte). Le dashboard lit les 50
dernières lignes au chargement, puis empile les actions en direct.

Rôles (voir `ops_log.sql`) : `web_anon` (SELECT via PostgREST), `authenticator`
(connexion PostgREST), `ops_writer` (INSERT pour les producteurs).

## Déploiement serveur

Prérequis : réseaux docker `docker_default` et `metabase_metabase_network`,
conteneurs `n8n` et `ubm_postgres` joignables, port `8088` libre.

```
git clone https://github.com/protazelbaze/dash.git /opt/stacks/dash
cd /opt/stacks/dash
cp .env.example .env         # renseigner PGRST_AUTH_PASSWORD (= mot de passe du rôle authenticator)
# jouer une fois le schéma (après avoir mis les mots de passe dans ops_log.sql) :
docker exec -i ubm_postgres psql -U ubm_user -d ubm_datas < ops_log.sql
docker compose up -d
```

Exposition via cloudflared (`dash.montaigne.contact` -> `127.0.0.1:8088`) + Access
« Équipe UBM ».

Mise à jour : `cd /opt/stacks/dash && git pull && docker compose up -d`
(un simple `git pull` suffit si seul `html/` change ; nginx sert le statique à chaud).
