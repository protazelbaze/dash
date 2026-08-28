-- Vue dashboard des métriques récolte + rôles PostgREST lecture seule.
-- À exécuter sur la base PAPERLESS (schéma recolte déjà présent).
-- Remplace CHANGE_ME_AUTH_RECOLTE, ou pose le mot de passe ensuite via ALTER ROLE.

create schema if not exists api;

create or replace view api.recolte_stats as
select
  c.source_key,
  c.label,
  c.derniere_recolte,
  c.total,
  c.importes,
  c.en_erreur,
  lr.discovered   as dernier_discovered,
  lr.stored       as dernier_stored,
  lr.imported     as dernier_imported,
  lr.status       as dernier_status,
  lr.finished_at  as dernier_run_at,
  (select count(*) from recolte.items i
     where i.source_key = c.source_key
       and i.stored_at is not null and i.imported_at is null) as a_confirmer,
  (select count(*) from recolte.a_relancer ar
     where ar.source_key = c.source_key) as a_relancer
from recolte.completude c
left join lateral (
  select * from recolte.runs r
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
