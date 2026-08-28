-- ops_log : journal d'opérations central UBM (base ubm_datas)
-- À exécuter sur ubm_postgres, base ubm_datas.
-- Remplace les deux mots de passe CHANGE_ME_* avant exécution.

-- 1. Table
create table if not exists public.ops_log (
  id      bigint generated always as identity primary key,
  ts      timestamptz not null default now(),
  source  text        not null,               -- 'n8n' | 'paperless' | 'docsia' | 'recolte' | 'dash'
  action  text        not null,               -- 'ingestion' | 'import' | 'status' | ...
  status  text        not null default 'info', -- 'ok' | 'error' | 'info'
  detail  jsonb,
  run_id  text
);
create index if not exists ops_log_ts_idx on public.ops_log (ts desc);

-- 2. Vue exposée par PostgREST (lecture seule, plus récent d'abord)
create schema if not exists api;
create or replace view api.ops_log as
  select id, ts, source, action, status, detail, run_id
  from public.ops_log
  order by ts desc;

-- 3. Rôles PostgREST
do $$
begin
  if not exists (select from pg_roles where rolname = 'web_anon') then
    create role web_anon nologin;
  end if;
  if not exists (select from pg_roles where rolname = 'authenticator') then
    create role authenticator noinherit login password 'CHANGE_ME_AUTH';
  end if;
end $$;

grant connect on database ubm_datas to authenticator;
grant usage on schema api to web_anon;
grant usage on schema public to web_anon;         -- la vue lit public.ops_log
grant select on public.ops_log to web_anon;
grant select on api.ops_log to web_anon;
grant web_anon to authenticator;                  -- authenticator peut endosser web_anon

-- 4. Rôle producteur (écriture seule sur la table)
do $$
begin
  if not exists (select from pg_roles where rolname = 'ops_writer') then
    create role ops_writer login password 'CHANGE_ME_WRITER';
  end if;
end $$;

grant connect on database ubm_datas to ops_writer;
grant usage on schema public to ops_writer;
grant insert on public.ops_log to ops_writer;

-- 5. Ligne de contrôle (facultatif)
insert into public.ops_log (source, action, status, detail)
values ('dash', 'init', 'info', '{"message":"ops_log initialisée"}');
