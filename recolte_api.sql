-- Vue dashboard des métriques récolte + rôles PostgREST lecture seule.
-- À exécuter sur la base PAPERLESS (schéma recolte déjà présent).
-- Idempotent : ré-exécutable pour mettre à jour la vue.
-- Remplace CHANGE_ME_AUTH_RECOLTE, ou pose le mot de passe ensuite via ALTER ROLE.

create schema if not exists api;

-- DROP puis CREATE : PostgreSQL refuse de retirer/renommer des colonnes via
-- CREATE OR REPLACE VIEW. Le grant sur la vue est reposé plus bas.
drop view if exists api.recolte_stats;
create view api.recolte_stats as
select
  c.source_key,
  c.label,
  c.derniere_recolte,                              -- date du dernier run terminé
  c.total,
  c.importes,
  c.en_erreur,
  ls.seance_date        as derniere_seance,        -- dernière séance (PV/CA)
  ls.total              as seance_total,           -- docs de cette séance
  ls.stored             as seance_stored,
  ls.importes           as seance_importes,        -- docs de cette séance dans Paperless
  lr.status             as dernier_run_status,
  lr.finished_at        as dernier_run_at,
  (select count(*) from recolte.items i
     where i.source_key = c.source_key
       and i.stored_at is not null and i.imported_at is null) as a_confirmer,
  (select count(*) from recolte.a_relancer ar
     where ar.source_key = c.source_key) as a_relancer
from recolte.completude c
left join lateral (
  select i.seance_date,
         count(*)                                          as total,
         count(*) filter (where i.stored_at is not null)   as stored,
         count(*) filter (where i.imported_at is not null) as importes
  from recolte.items i
  where i.source_key = c.source_key and i.seance_date is not null
  group by i.seance_date
  order by i.seance_date desc
  limit 1
) ls on true
left join lateral (
  select status, finished_at
  from recolte.runs r
  where r.source_key = c.source_key
  order by started_at desc
  limit 1
) lr on true;

-- Rôles PostgREST (cluster Paperless, indépendant du cluster ubm)
do $$
begin
  if not exists (select from pg_roles where rolname = 'web_anon') then
    create role web_anon nologin;
  end if;
  if not exists (select from pg_roles where rolname = 'authenticator') then
    create role authenticator noinherit login password 'CHANGE_ME_AUTH_RECOLTE';
  end if;
end $$;

grant connect on database paperless to authenticator;
grant usage on schema api to web_anon;
grant usage on schema recolte to web_anon;
grant select on api.recolte_stats to web_anon;
grant select on recolte.completude, recolte.a_relancer, recolte.runs, recolte.items to web_anon;
grant web_anon to authenticator;
