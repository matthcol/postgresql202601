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

select 'position' as "table", count(*) as nb_rows from position
UNION
select 'position_2024' as "table", count(*) as nb_rows from position_2024
UNION
select 'position_2025' as "table", count(*) as nb_rows from position_2025
UNION
select 'position_2026' as "table", count(*) as nb_rows from position_2026;


select *
from position
where horodatage >= '2025-07-01'
;


create index idx_position_geom on position using gist(geom_pt);
select * from pg_indexes where tablename like 'position%';


create unique index idx_departement_insee_dep on departement_shp (insee_dep); -- ou unique constraint

-- passage dans les Landes en 2025 : partition explicite
select
    *
from
    position_2025 p,
    departement_shp d
where
    d.insee_dep = '40'
    and st_within(p.geom_pt, d.geom)
;

select
    *
from
    position p,
    departement_shp d
where
    d.insee_dep = '40'
    and st_within(p.geom_pt, d.geom)
    and p.horodatage >= '2025-01-01 00:00Z'::timestamptz
    and p.horodatage < '2026-01-01 00:00Z'::timestamptz
;

-- nouvelle année:

insert into position (horodatage, geom_pt, company)
values ('2027-02-28 12:34Z'::timestamptz, 'POINT (100000 6000000)', 'World Company');
-- [23514] ERROR: no partition of relation "position" found for row
--   Détail : Partition key of the failing row contains (horodatage) = (2027-02-28 12:34:00+00).

create table position_2027
partition of position
for values from ('2027-01-01 00:00Z'::timestamptz) to ('2028-01-01 00:00Z'::timestamptz);

insert into position (horodatage, geom_pt, company)
values ('2027-02-28 12:34Z'::timestamptz, 'POINT (100000 6000000)', 'World Company');

-- archivage de la partition 2024 avec pg_dump

-- suppresion vieille partition (archivée)
drop table position_2024;


-- reintegration d'une partition archivée

-- DDL : recreation de la table partition
CREATE TABLE formation.position_2024 (
    id bigint DEFAULT nextval('formation.position_id_seq'::regclass) CONSTRAINT position_id_not_null NOT NULL,
    horodatage timestamp with time zone CONSTRAINT position_horodatage_not_null NOT NULL,
    geom_pt public.geometry(Point,2154) CONSTRAINT position_geom_pt_not_null NOT NULL,
    company character varying(100)
);

-- Data : restauration data avec psql ou pg_restore
-- psql -U dax -d dbcity -f archive-position_2024-data.sql

-- reattacher la partition
ALTER TABLE ONLY position ATTACH PARTITION formation.position_2024 FOR VALUES FROM ('2024-01-01 00:00:00+00') TO ('2025-01-01 00:00:00+00');

select * from pg_indexes where tablename like 'position%';

---------------------------------------------------------------------
SELECT
    grantee,
    table_schema,
    table_name,
    privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'dax';


----------------------------------------------------------------------------------------------------
--
drop table position;

-- 1st level : table principale partitionnée par compagnie
create table position(
  position_id bigserial,
  horodatage timestamptz not null,
  company_id int not null,  -- TODO : FK vers table company
  geom_pt geometry(Point, 2154) not null,
  constraint pk_position primary key(position_id, company_id, horodatage)
) partition by list(company_id);

create index idx_position_geom_pt on position using gist(geom_pt);

-- 2nd level : partition par compagnie partitionnée par horodatage
create table position_company1
    partition of position for values in (1)
    partition by range(horodatage)
;

create table position_company2
    partition of position for values in (2)
    partition by range(horodatage)
;

create table position_company3
    partition of position for values in (3)
    partition by range(horodatage)
;

create table position_company_dev
    partition of position for values in (4,5,7)
    partition by range(horodatage)
;

-- 3d level compagnie + horodatage
create table position_company1_2024
    partition of position_company1
        for values from ('2024-01-01 00:00Z'::timestamptz) to ('2025-01-01 00:00Z'::timestamptz)
;

create table position_company1_2025
    partition of position_company1
        for values from ('2025-01-01 00:00Z'::timestamptz) to ('2026-01-01 00:00Z'::timestamptz)
;

create table position_company1_2026
    partition of position_company1
        for values from ('2026-01-01 00:00Z'::timestamptz) to ('2027-01-01 00:00Z'::timestamptz)
;

create table position_company2_2024
    partition of position_company2
        for values from ('2024-01-01 00:00Z'::timestamptz) to ('2025-01-01 00:00Z'::timestamptz)
;

create table position_company2_2025
    partition of position_company2
        for values from ('2025-01-01 00:00Z'::timestamptz) to ('2026-01-01 00:00Z'::timestamptz)
;

create table position_company2_2026
    partition of position_company2
        for values from ('2026-01-01 00:00Z'::timestamptz) to ('2027-01-01 00:00Z'::timestamptz)
;

create table position_company3_2024
    partition of position_company3
        for values from ('2024-01-01 00:00Z'::timestamptz) to ('2025-01-01 00:00Z'::timestamptz)
;

create table position_company3_2025
    partition of position_company3
        for values from ('2025-01-01 00:00Z'::timestamptz) to ('2026-01-01 00:00Z'::timestamptz)
;

create table position_company3_2026
    partition of position_company3
        for values from ('2026-01-01 00:00Z'::timestamptz) to ('2027-01-01 00:00Z'::timestamptz)
;

create table position_company_dev_2024
    partition of position_company_dev
        for values from ('2024-01-01 00:00Z'::timestamptz) to ('2025-01-01 00:00Z'::timestamptz)
;

create table position_company_dev_2025
    partition of position_company_dev
        for values from ('2025-01-01 00:00Z'::timestamptz) to ('2026-01-01 00:00Z'::timestamptz)
;

create table position_company_dev_2026
    partition of position_company_dev
        for values from ('2026-01-01 00:00Z'::timestamptz) to ('2027-01-01 00:00Z'::timestamptz)
;

CREATE OR REPLACE FUNCTION generer_positions_fictives(
    p_company_id integer,
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
        INSERT INTO position (company_id, horodatage, geom_pt)
        VALUES (
                p_company_id,
            horodatage_aleatoire,
            ST_SetSRID(ST_MakePoint(x_coord, y_coord), 2154)
        );

        compteur := compteur + 1;
    END LOOP;

    RETURN compteur;
END;
$$;

drop function generer_positions_fictives(nb_positions integer, date_debut timestamp with time zone, date_fin timestamp with time zone);

SELECT generer_positions_fictives(
    1,
    50000,
    '2024-01-01'::TIMESTAMPTZ,
    '2026-01-20'::TIMESTAMPTZ
);

SELECT generer_positions_fictives(
    2,
    100000,
    '2024-01-01'::TIMESTAMPTZ,
    '2026-01-22'::TIMESTAMPTZ
);

SELECT generer_positions_fictives(
    3,
    500000,
    '2024-01-01'::TIMESTAMPTZ,
    '2026-01-23 12:00'::TIMESTAMPTZ
);

SELECT generer_positions_fictives(
    7,
    5000,
    '2024-01-01'::TIMESTAMPTZ,
    '2026-01-22'::TIMESTAMPTZ
);

select 1 as level, 'position' as "table", count(*) as nb_rows from position

UNION
select 2 as level, 'position_company1' as "table", count(*) as nb_rows from position_company1
UNION
select 2 as level, 'position_company2' as "table", count(*) as nb_rows from position_company2
UNION
select 2 as level, 'position_company3' as "table", count(*) as nb_rows from position_company3
UNION
select 2 as level, 'position_company_dev' as "table", count(*) as nb_rows from position_company_dev

UNION
select 3 as level, 'position_company1_2024' as "table", count(*) as nb_rows from position_company1_2024
UNION
select 3 as level, 'position_company1_2025' as "table", count(*) as nb_rows from position_company1_2025
UNION
select 3 as level, 'position_company1_2026' as "table", count(*) as nb_rows from position_company1_2026

UNION
select 3 as level, 'position_company2_2024' as "table", count(*) as nb_rows from position_company2_2024
UNION
select 3 as level, 'position_company2_2025' as "table", count(*) as nb_rows from position_company2_2025
UNION
select 3 as level, 'position_company2_2026' as "table", count(*) as nb_rows from position_company2_2026

UNION
select 3 as level, 'position_company3_2024' as "table", count(*) as nb_rows from position_company3_2024
UNION
select 3 as level, 'position_company3_2025' as "table", count(*) as nb_rows from position_company3_2025
UNION
select 3 as level, 'position_company3_2026' as "table", count(*) as nb_rows from position_company3_2026
;


select
    '2025' as year,
    p.company_id,
    count(*)
from
    position p,
    departement_shp d
where
    d.insee_dep = '40'
    and st_within(p.geom_pt, d.geom)
    and p.horodatage >= '2025-01-01 00:00Z'::timestamptz
    and p.horodatage < '2026-01-01 00:00Z'::timestamptz
group by p.company_id
;


select
    ST_Extent(p.geom_pt) as geom_40_2025
from
    position p,
    departement_shp d
where
    d.insee_dep = '40'
    and st_within(p.geom_pt, d.geom)
    and p.horodatage >= '2025-01-01 00:00Z'::timestamptz
    and p.horodatage < '2026-01-01 00:00Z'::timestamptz
    and p.company_id = 1
;

select
    ST_Extent(p.geom_pt) as geom_40_2025
from
    position p,
    departement_shp d
where
    d.insee_dep = '40'
    and st_within(p.geom_pt, d.geom)
    and p.horodatage >= '2025-01-01 00:00Z'::timestamptz
    and p.horodatage < '2025-04-01 00:00Z'::timestamptz
    and p.company_id = 1
;

-- apres archivage
drop table position_company1_2024;
drop table position_company2_2024;
drop table position_company3_2024;
drop table position_company_dev_2024;

----------------------------------------------------------------------------------------------------------------------
-- jointures

create table company (
    company_id serial constraint pk_company primary key,
    name varchar(100) not null,
    country varchar(3) not null
);

insert into company (name, country)
values
    ('Quest', 'FR'),
    ('Black Mesa', 'US'),
    ('Aperture Science', 'DE'),
    ('Stark Industry', 'US'),
    ('Quest_dev', 'FR'),
    ('World Company', 'LU'),
    ('Karnott', 'RO')
;

alter table position
    add constraint fk_position_company
    foreign key (company_id)
    references company(company_id);


select
    c.code_insee,
    cy.name,
    c.nom_standard,
    c.dep_code,
    c.altitude_maximale,
    st_area(cs.geom) as comm_area,
    cs.geom,
    count(p.position_id) as nb_pos
from
    communes_fr_pt c
    join commune_shp cs on c.code_insee = cs.insee_com
    join departement_shp d on cs.insee_dep = d.insee_dep
    join position p on st_within(p.geom_pt, d.geom)
    join company cy on p.company_id = cy.company_id
where
    c.altitude_maximale > 1000
   and st_area(cs.geom) > 10_000_000
   and st_ymax(d.geom) < 6418792.1
   and p.horodatage between '2025-02-01'::timestamptz and '2025-04-30'::timestamptz
   and cy.name = 'Black Mesa'
group by c.code_insee, cs.gid, cy.company_id
order by c.altitude_maximale desc
;

select st_ymin(geom), nom
from commune_shp
where nom ilike 'bordeaux';


-- draft : pb => pas de ville du 06 malgré le left join (where qui fait disparaitre)
select
    c.code_insee,
    c.nom_standard,
    c.dep_code,
    c.altitude_maximale,
    st_area(cs.geom) as comm_area,
    min(st_area(d.geom)) as dep_area,
    count(*) as nb_position
from
    communes_fr_pt c
    join commune_shp cs on c.code_insee = cs.insee_com
    left join (select * from departement_shp where insee_dep <> '06') d on cs.insee_dep = d.insee_dep
    left join position p on st_within(p.geom_pt, d.geom)
where
    c.code_insee in ('65192', '65138', '31404', '06127')
  and p.horodatage between '2025-02-01'::timestamptz and '2025-04-30'::timestamptz
  and p.company_id = 1
group by c.code_insee, cs.gid
;

-- solutions : or is null, predicat ds la sous-requet ou le on du join
select
    c.code_insee,
    c.nom_standard,
    c.dep_code,
    c.altitude_maximale,
    st_area(cs.geom) as comm_area,
    -- min(st_area(d.geom)) as dep_area,
    coalesce(min(st_area(d.geom)), 0) as dep_area,  -- en réalité souvent sur la somme (total)
    count(p.position_id) as nb_position  -- 0 qd pas de correspondant
from
    communes_fr_pt c
    join commune_shp cs on c.code_insee = cs.insee_com
    left join (
        select *
        from departement_shp
        where insee_dep <> '06'
    ) d on cs.insee_dep = d.insee_dep
    left join (
        select *
        from position
        where
            horodatage between '2025-02-01'::timestamptz and '2025-04-30'::timestamptz
            and company_id = 1
    ) p on st_within(p.geom_pt, d.geom)
where
    c.code_insee in ('65192', '65138', '31404', '06127')
group by c.code_insee, cs.gid
;

-- requete avec fenêtre

select
    code_insee, code_postal, nom_standard, dep_code,
    count(code_insee) over (partition by dep_code)
from communes_fr_pt
where reg_nom = 'Nouvelle-Aquitaine'
;


