-- statistiques sur les colonnes de tables
-- alimentée par ANALYZE
-- => plan d'execution
select * from pg_stats;

-- Sessions en cours:
-- pid : process enfant postgres en charge de la session cliente
-- datname, usename : db + user
-- application_name, client_addr, client_hostname
-- state, state_change : state + timestamp
-- query : current or last query
select * from pg_stat_activity
where datname = 'dbcity';


-- en dba:
select pg_cancel_backend(84);
select pg_terminate_backend(84);  -- ou kill processus OS

-- stats sur les requetes
select * from pg_available_extensions; -- pg_stat_statements
select * from pg_extension;

-- en dba:
create extension pg_stat_statements;
-- + postgresql.conf:
-- shared_preload_libraries = 'pg_stat_statements'         # (change requires restart)

select * from pg_stat_statements;
select pg_stat_statements_reset();

select * from pg_stat_statements
order by mean_exec_time desc;

-----------------------------------------------------------------------
-- grande base ou base multi-tenant

-- stratégie 1 :
--      1 schema par client + search_path ou nom de schema explicite
--      1 user db par client/schema

-- stratégie 2 : partitionnement
-- Exemple

-- table globale
drop table position;

create table position(
  id bigserial,
  horodatage timestamptz not null,
  geom_pt geometry(Point, 2154) not null
) partition by range(horodatage);

-- PK composite
alter table position
add constraint pk_position
primary key(id, horodatage);

select * from pg_indexes where tablename like 'position%';

create table position_2024
partition of position
for values from ('2024-01-01 00:00Z'::timestamptz) to ('2025-01-01 00:00Z'::timestamptz);

create table position_2025
partition of position
for values from ('2025-01-01 00:00Z'::timestamptz) to ('2026-01-01 00:00Z'::timestamptz);

create table position_2026
partition of position
for values from ('2026-01-01 00:00Z'::timestamptz) to ('2027-01-01 00:00Z'::timestamptz);

alter table position add column company varchar(100);

CREATE OR REPLACE FUNCTION generer_positions_fictives(
    nb_positions INTEGER DEFAULT 1000,
    date_debut TIMESTAMPTZ DEFAULT NOW() - INTERVAL '30 days',
    date_fin TIMESTAMPTZ DEFAULT NOW()
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    i INTEGER;
    horodatage_aleatoire TIMESTAMPTZ;
    x_coord DOUBLE PRECISION;
    y_coord DOUBLE PRECISION;
    compteur INTEGER := 0;
BEGIN
    -- Boucle pour générer les positions
    FOR i IN 1..nb_positions LOOP
        -- Générer un horodatage aléatoire entre date_debut et date_fin
        horodatage_aleatoire := date_debut +
            (RANDOM() * (date_fin - date_debut));

        -- Générer des coordonnées aléatoires en Lambert 93 (EPSG:2154)
        -- Exemple pour la France métropolitaine approximativement :
        -- X entre 100000 et 1200000
        -- Y entre 6000000 et 7100000
        x_coord := 100000 + (RANDOM() * 1100000);
        y_coord := 6000000 + (RANDOM() * 1100000);

        -- Insérer la position
        INSERT INTO position (horodatage, geom_pt)
        VALUES (
            horodatage_aleatoire,
            ST_SetSRID(ST_MakePoint(x_coord, y_coord), 2154)
        );

        compteur := compteur + 1;
    END LOOP;

    RETURN compteur;
END;
$$;

SELECT generer_positions_fictives(
    50000,
    '2024-01-01'::TIMESTAMPTZ,
    '2026-01-20'::TIMESTAMPTZ
);

select count(*) from position;



