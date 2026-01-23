select
	1.2::numeric,
	1.2::real,
	0.1::real * 3, -- 0.30000000447034836
	0.1::numeric * 3 -- 0.3
;

select 
	max(char_length(nom_standard)),
	max(octet_length(nom_standard)),
	max(length(nom_standard)) 
from communes_fr;

select
	char_length('Trèbes'),
	length('Trèbes'),
	octet_length('Trèbes'),
	char_length('東京'),
	octet_length('東京'),
	char_length('🦜🍻💕☃️🐞🍓'),
	octet_length('🦜🍻💕☃️🐞🍓')
;

select 
	'true'::boolean,
	'on'::boolean,
	'yes'::boolean,
	1::boolean,
	'false'::boolean,
	'off'::boolean,
	'no'::boolean,
	0::boolean
;

-- like/ilike
select *
from communes_fr
where nom_standard like 'Trèb%';

select *
from communes_fr
where nom_standard ilike 'trèb%';  -- CI

-- similar : regex p du standard SQL

-- regexp POSIX: ~ (match CS) / ~* (match CI)
select *
from communes_fr
where nom_standard ~* '[az].{10,15}s'
;

select *
from communes_fr
where nom_standard ~* '(-[^-]*){5,}'
;

-- TODO: FTS, tri (collation)

-- données temporelles

-- verif postgresql.conf (ou env variables)

-- log_timezone = 'Europe/Paris'
-- timezone = 'Europe/Paris'
select
	CURRENT_DATE,
	CURRENT_TIME,
	CURRENT_TIME::time, -- i.e. time without time zone
	CURRENT_TIME::timetz, -- i.e. time with time zone
	CURRENT_TIMESTAMP,
	CURRENT_TIMESTAMP::timestamp, -- i.e. timestamp without time zone
	CURRENT_TIMESTAMP::timestamptz -- i.e. timestamp with time zone
;

-- time / timestamp : calcul avec le type interval
select 
	current_timestamp::timestamp - '2024-02-29 00:00'::timestamp,
	current_timestamp::timestamp - '679 days 11:50:01.807177'::interval,
	current_timestamp::timestamp + '2 hours 15 minutes'::interval,
	current_timestamp::timestamp + '1 day + 25 hours 15 minutes'::interval
;

-- date : calcul en nb jours (int)
select 
	current_date + 3,
	current_date - '2024-02-29'::date,
	current_date::timestamp - '2024-02-29'::date::timestamp
;

select
	'2024-02-29 12:06'::timestamp::date,
	'2024-02-29 12:06'::timestamp::time
;

select
	'2024-02-29 12:06+01'::timestamptz AT TIME ZONE 'America/Los_Angeles',
	'2024-02-29 11:06Z'::timestamptz AT TIME ZONE 'America/Los_Angeles',
	'2024-01-15 10:00:00'::timestamp AT TIME ZONE 'America/New_York' AT TIME ZONE 'Europe/Paris'
;

-- années bisextile
select 
	'2000-02-29'::date
	, '2024-02-29'::date
	-- , '2100-02-29'::date -- not a leap year
;

-- data gis
alter user dax set search_path = formation,public,tiger,topology;
set search_path = formation,public,tiger,topology;
show search_path;

alter table communes_fr_pt
add constraint pk_communes_fr_pt primary key(code_insee);

create index idx_communes_fr_pt_cp on communes_fr_pt (code_postal);

CREATE INDEX idx_communes_fr_pt_geometry ON communes_fr_pt USING gist (geometry);

-- SRID : exemples
-- * WGS 84 / Mercator (EPSG:4326)
-- * RGF93 / Lambert-93 (Code EPSG : 2154)

select
	c.nom_standard,
	c.latitude_mairie,
	c.longitude_mairie,
	c.latitude_centre,
	c.longitude_centre,
	c.geometry,
	ST_SRID(c.geometry),  --  WGS 84 (EPSG:4326)
	ST_GeometryType(c.geometry) -- ST_Point
from communes_fr_pt c
where c.nom_standard in ('Dax', 'Mont-de-Marsan');


select
	c.nom_standard,
	c.longitude_mairie, c.latitude_mairie,
	c.longitude_centre, c.latitude_centre,
	ST_MakePoint(c.longitude_mairie, c.latitude_mairie) as pt_mairie,
	ST_MakePoint(c.longitude_centre, c.latitude_centre) as pt_centre,
	ST_ASText(c.geometry),
	ST_GeomFromText('POINT(-1.052000045776367 43.70899963378906)')
from communes_fr_pt c
where c.nom_standard in ('Dax', 'Mont-de-Marsan');


with commune_poi as (
	select geometry
	from communes_fr_pt
	where nom_standard = 'Dax'
) select 
	c.nom_standard,
	c.code_postal,
	ST_distance(cpoi.geometry, c.geometry) as dist_poi,  -- unité du SRID
	cpoi.geometry <-> c.geometry as dist_poi2,
	ST_distance(cpoi.geometry::geography, c.geometry::geography) as dist_poi_m, -- calcul exact
	cpoi.geometry::geography <-> c.geometry::geography as dist_poi_m2, -- moins precis (utilise les bounding box)
	c.geometry,
	cpoi.geometry as geom_poi
  from communes_fr_pt c, commune_poi cpoi
  where 
  	-- ST_distance(cpoi.geometry, c.geometry) <= 0.20
	  ST_distance(cpoi.geometry::geography, c.geometry::geography) <= 20000
  order by dist_poi_m
;

select
	ST_makebox2d(
		ST_makepoint(-1.052, 43.709),
		ST_makepoint(-0.501, 43.891)
	)
;

select
	c.nom_standard,
	c.code_postal,
	c.geometry
from communes_fr_pt c
where 
	-- est contenu
	c.geometry @ ST_makebox2d(
		ST_makepoint(-1.052, 43.709), -- Dax
		ST_makepoint(-0.501, 43.891)  -- Mont2
	)
;

select
	c.nom_standard,
	c.code_postal,
	c.geometry
from communes_fr_pt c
where 
	-- contient : ''~' ou 'st_contains' ou 'st_within'
	ST_makebox2d(
		ST_makepoint(-1.052, 43.709), -- Dax
		ST_makepoint(-0.501, 43.891)  -- Mont2
	) ~ c.geometry
;


select * 
from pg_indexes 
where schemaname = 'formation'
order by tablename;

select 
	code_insee,
	code_postal,
	nom_standard
from communes_fr_pt
where nom_standard = 'Dax'  -- full scan table car pas d'index sur le nom
;

select 
	code_insee,
	code_postal,
	nom_standard
from communes_fr_pt
where code_insee = '40088'  -- index PK code_insee
;

select 
	code_insee,
	code_postal,
	nom_standard
from communes_fr_pt
where code_postal = '40100'  -- index cp
;

select
	count(distinct code_insee)::real / count(code_insee)::real,
	count(distinct code_postal)::real / count(code_postal)::real,
	count(distinct nom_standard)::real / count(nom_standard)::real
from communes_fr_pt;  -- 1	0.17207718	0.93568057

select * from pg_stats 
where schemaname = 'formation'
order by tablename;

-- selectivité : stat ndistinct
--                  * si < 0 : - selectivité (bonne)
--					* si > 0 : nb de valeurs distinctes

create index idx_communes_fr_pt_population 
on communes_fr_pt(population); -- default BTREE  (selectivité -0.15660512)

select *
from communes_fr_pt
where population > 100000
order by population; -- utilise l'index

-- entretien des stats (auto)
analyze communes_fr_pt;
vacuum analyze communes_fr_pt;

-- collate : réglable base, table, colonne, query
select 
	code_postal,
	nom_standard
from communes_fr_pt
where dep_code = '40'
order by nom_standard collate "fr-FR-x-icu";

SELECT * FROM pg_collation where collname ilike '%fr%';
	













