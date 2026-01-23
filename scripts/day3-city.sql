----------------------------------------------------------------------
-- DAY 3 : base dbcity, user dax
----------------------------------------------------------------------

-- qqs communes n'ont pas de coordonnées pour le centre
select *
from communes_fr_pt
where latitude_centre is null;

-- Requête suivante utilise les indexes suivants:
-- * code_postal : BTREE
-- * codes_postaux : GIN
-- NB : attention à l'homegeneité des types de l'opérateur <@ ou @>
select *
from communes_fr_pt
where 
	code_postal = '31200'
	or ARRAY['31200']::char(5)[] <@ codes_postaux
;

-- Requête suivante
-- utilise l'index GIS sur la colonne geometry (WSG 84: 4326)
-- type : geometry(Point,4326)
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

-----------------------------------------------------------
-- coordonnées en Lambert 93 (2154) : stocker et/ou indexer ?

-- sol 1 : stocker et indexer => recherche + calcul
-- sol 2 (alt) : indexer uniquement => recherche uniquement

alter table communes_fr_pt
add column geom_l93 geometry(Point, 2154);

update communes_fr_pt
set geom_l93 = ST_Transform(geometry, 2154);

create index idx_communes_fr_pt_geom93 on communes_fr_pt using GIST(geom_l93);

show search_path;

select
	nom_standard,
	geom_l93,
	ST_AsText(geom_l93) as coords_93,  -- POINT(373488.47959506797 6298376.002684743)
	ST_AsText(geometry) as coords_84
from communes_fr_pt
where nom_standard = 'Dax'
;


select
	nom_standard,
	geom_l93
from communes_fr_pt
where 
	dep_code = '40'
	and population > 5000
;

select
	code_insee,
	nom_standard,
	code_postal,
	ST_distance(geom_l93, 'SRID=2154;POINT(373488.47959506797 6298376.002684743)'::geometry) 
		/ 1000.0 as distance_mairie_dax
from communes_fr_pt
where 
    ST_distance(geom_l93, 'SRID=2154;POINT(373488.47959506797 6298376.002684743)'::geometry) < 10000
order by distance_mairie_dax
;

-- même chose avec distance des centres au lieu des mairies
with commune_centre93 as (
	select
		code_insee,
		nom_standard,
		latitude_centre,
		longitude_centre,
		ST_transform(
			ST_SetSRID(ST_MakePoint(longitude_centre, latitude_centre), 4326),
			2154
		) as geom_centre93
	from communes_fr_pt
) -- select * from communes_fr_pt
, commune_dax93 as (
	select 
		code_insee as code_insee_dax,
		nom_standard as nom_standard_dax,
		latitude_centre as latitude_centre_dax,
		longitude_centre as longitude_centre_dax,
		geom_centre93 as geom_centre93_dax
	from commune_centre93
	where code_insee = '40088'
) -- select * from commune_dax93
, commune_dist as (
	select
		*,
		ST_distance(c.geom_centre93, d.geom_centre93_dax) as distance_dax
	from 
		commune_centre93 c,
		commune_dax93 d
) -- select * from commune_dist
select *
from commune_dist
where distance_dax < 10000
order by distance_dax
;

-- idem sur 2 villes : Dax et Mont2
with commune_centre93 as (
	select
		code_insee,
		nom_standard,
		latitude_centre,
		longitude_centre,
		ST_transform(
			ST_SetSRID(ST_MakePoint(longitude_centre, latitude_centre), 4326),
			2154
		) as geom_centre93
	from communes_fr_pt
) -- select * from communes_fr_pt
, commune_ref93 as (
	select 
		code_insee as code_insee_ref,
		nom_standard as nom_standard_ref,
		latitude_centre as latitude_centre_ref,
		longitude_centre as longitude_centre_ref,
		geom_centre93 as geom_centre93_ref
	from commune_centre93
	where code_insee in ('40088', '40192')
) -- select * from commune_dax93
, commune_dist as (
	select
		*,
		ST_distance(c.geom_centre93, d.geom_centre93_ref) as distance_ref
	from 
		commune_centre93 c,
		commune_ref93 d
) -- select * from commune_dist
select *
from commune_dist
where distance_ref< 10000
order by code_insee_ref, distance_ref
;

-- NB: bcp plus long sans indexes supplémentaires
-- => ajout stockage/indexes et remaniement
-- calcul distance oblige stockage (ou index include)
alter table communes_fr_pt 
add column geom_centre93 geometry(Point, 2154) NULL;

update communes_fr_pt 
set geom_centre93 = ST_transform(
			ST_SetSRID(ST_MakePoint(longitude_centre, latitude_centre), 4326),
			2154
		)
where latitude_centre is not null;

create index idx_communes_fr_pt_geom93_centre on communes_fr_pt using GIST(geom_centre93)
where geom_centre93 is not null;

-- reecriture requete => 1mn ramené à 100ms
with commune_ref93 as (
	select 
		code_insee as code_insee_ref,
		nom_standard as nom_standard_ref,
		latitude_centre as latitude_centre_ref,
		longitude_centre as longitude_centre_ref,
		geom_centre93 as geom_centre93_ref
	from communes_fr_pt
	where code_insee in ('40088', '40192')
) -- select * from commune_ref93
, commune_dist as (
	select
		*,
		ST_distance(c.geom_centre93, d.geom_centre93_ref) as distance_ref
	from 
		communes_fr_pt c,
		commune_ref93 d
) -- select * from commune_dist
select *
from commune_dist
where distance_ref < 10000
order by code_insee_ref, distance_ref
;


------------------------------------------------------
-- import shapes communes + departement avec shp2pgsql
------------------------------------------------------

-- executer : day3-import-shapes.sh

-- verifier les indexes créés à l'importation
select * from pg_indexes where schemaname = 'formation'
order by tablename;

-- Dax et Mont2
select *
from commune_shp
where insee_com in ('40088', '40192')
;

-- voir les coords WSG 84
select 
	insee_com,
	nom,
	st_transform(geom, 4326) as geom84
from commune_shp
where insee_com in ('40088', '40192')
;

-- voir les shapes du 40 et 64
select 
	insee_dep,
	nom,
	st_transform(geom, 4326) as geom84
from departement_shp
where insee_dep in ('40', '64')
;

-- NB: admin search_path
select * from pg_roles;

SELECT name, setting, source 
FROM pg_settings 
WHERE name = 'search_path';

-- settings user +base prioritaire à user tt court
SELECT *
FROM pg_db_role_setting
;

--------------------------------------------------------
-- GIS : 2D

select 
	st_extent(geom) as box40, -- box2d
	st_envelope(geom) as env40 -- polygon
from departement_shp
where insee_dep = '40'
group by insee_dep, geom;


select 
	c.insee_com,
	c.nom,
	c.population,
	c.insee_dep,
	d.nom as dep_nom,
	c.geom
from 
	commune_shp c, departement_shp d
where 
	d.insee_dep = '40'
	and St_within(
		c.geom,  
		st_envelope(d.geom)
	)
order by c.insee_dep
;

select 
	c.insee_com,
	c.nom,
	c.population,
	c.insee_dep,
	d.nom as dep_nom,
	c.geom,
	st_simplify(d.geom, 1000) as geom_dep_simpl
from 
	commune_shp c, departement_shp d
where 
	d.insee_dep = '40'
	and St_within(
		c.geom,  
		st_simplify(d.geom, 1000)
	)
order by c.insee_dep
;

with dept40 as (
	select 
		insee_dep,
		nom,
		st_extent(geom) as box_dep_simpl	
	from departement_shp
	where insee_dep = '40'
	group by gid -- PK
)
select 
	c.insee_com,
	c.nom,
	c.population,
	c.insee_dep,
	d.nom as dep_nom,
	c.geom,
	d.box_dep_simpl
from 
	commune_shp c, dept40 d
where
	st_contains(
		st_setsrid(d.box_dep_simpl::geometry, 2154),
		c.geom
	)
order by c.insee_dep
;

with dept40 as (
	select 
		insee_dep,
		nom,
		st_extent(geom) as box_dep_simpl	
	from departement_shp
	where insee_dep = '40'
	group by gid -- PK
)
select 
	c.insee_com,
	c.nom,
	c.population,
	c.insee_dep,
	d.nom as dep_nom,
	c.geom,
	d.box_dep_simpl
from 
	commune_shp c, dept40 d
where
	c.geom && d.box_dep_simpl
order by c.insee_dep
;

-- ajout distance centre des Landes
select 
	c.insee_com,
	c.nom,
	c.population,
	c.insee_dep,
	d.nom as dep_nom,
	c.geom,
	st_distance(
		st_centroid(d.geom), -- st_centroid(st_envelope(d.geom))
		st_centroid(c.geom)
	) / 1000.0 as distance_km_centre40,
	st_area(d.geom) / 1000000.0 as area_dept_km2 ,
	st_area(st_envelope(d.geom)) / 1000000.0 as area_env_dept_km2
from 
	commune_shp c, departement_shp d
where 
	d.insee_dep = '40'
	and St_within(
		c.geom,  
		st_envelope(d.geom)
	)
order by distance_km_centre40;

with commune_box40 as (
	select 
		c.insee_com,
		c.nom,
		c.population,
		c.insee_dep,
		d.nom as dep_nom,
		c.geom,
		st_distance(
			st_centroid(d.geom), -- st_centroid(st_envelope(d.geom))
			st_centroid(c.geom)
		) / 1000.0 as distance_km_centre40,
		st_area(d.geom) / 1000000.0 as area_dept_km2 ,
		st_area(st_envelope(d.geom)) / 1000000.0 as area_env_dept_km2
	from 
		commune_shp c, departement_shp d
	where 
		d.insee_dep = '40'
		and St_within(
			c.geom,  
			st_envelope(d.geom)
		)
) -- select * from commune_box40;
select
	insee_dep
	, avg(distance_km_centre40) distance_moy
	, sum(st_area(geom)) / 1000000.0 as area_commune_tot_s
	, st_area(st_union(geom)) / 1000000.0 as area_commune_tot_u
	, st_area(st_collect(geom)) / 1000000.0 as area_commune_tot_c
from commune_box40
group by insee_dep
order by area_commune_tot_s desc
;

-- NB : Qqs fonctions agrégation GIS
-- * ST_Union : fusionne les geometries
-- * ST_Collect : rassemblement (multi) sans fusion
-- * ST_Extent : bounding box agregée
-- * ST_MakeLine : agrège points en Ligne
-- * ST_Polygonize : agrège lignes en polygone
-- * ...

with itineraire as (
	select
		string_agg(c.nom_standard, ', ' order by st_y(c.geom_centre93)) texte,
		ST_MakeLine(c.geom_centre93 order by st_y(c.geom_centre93)) geom
	from communes_fr_pt c
	where c.dep_code = '40'
		and c.nom_standard in ('Soustons', 'Dax', 'Mont-de-Marsan', 'Mimizan')
) select
	texte,
	st_asText(geom),
	geom
from itineraire
;

-- ordre en entrée
WITH communes_ordre AS (
    SELECT 
		unnest(ARRAY['Soustons', 'Dax', 'Mont-de-Marsan', 'Mimizan']) AS nom,
        generate_series(1, 4) AS ordre
), itineraire as (
	select
		string_agg(c.nom_standard, ', ' order by o.ordre) texte,
		ST_MakeLine(c.geom_centre93 order by o.ordre) geom
	from communes_fr_pt c join communes_ordre o on c.nom_standard = o.nom and c.dep_code = '40'
) select
	texte,
	st_length(geom) / 1000 as distance_km,
	st_asText(geom),
	geom
from itineraire
;

-----------------------------------------------------------------
-- Exports: CSV, kml, geojson, shp, ...
select
	nom,
	st_astext(geom),
	st_askml(geom),
	st_asgeojson(geom)
from commune_shp
where insee_dep = '40'
;

-- avec copy on peut fabriquer tout format texte (CSV, json, kml)
-- CSV (COPY : SQL côté serveur, \copy côté client)

-- day3-export-tsv.sql (en 1 ligne)
\copy (
	select
		nom,
		st_astext(geom) as geom
	from commune_shp
	where insee_dep = '40'
) TO 'comunes_40.tsv' with (
	FORMAT csv, delimiter E'\t', encoding 'UTF8', header
)

-- draft KML
\copy (
    SELECT ST_AsKML(geom) AS kml
    FROM commune_shp
	where insee_dep = '40'
) TO 'communes_40.kml';

-- avec meta-données et racine et entetess XML
-- voir : day3-export-kml.sql ou day3-export-kml.sh avec ogr2ogr
\copy (
    SELECT 
        '<?xml version="1.0" encoding="UTF-8"?>' ||
        '<kml xmlns="http://www.opengis.net/kml/2.2">' ||
        '<Document>' ||
        '<name>Communes Département 40</name>' ||
        string_agg(
            '<Placemark>' ||
            '<name>' || nom || '</name>' ||
            '<description>population' || population  || '</description>' ||
			ST_AsKML(geom) ||
			'</Placemark>', 
			'' -- delimiter
		) ||
		'</Document></kml>'
    FROM commune_shp
	where insee_dep = '40'
) TO 'communes_40.kml' with (encoding 'UTF8');

-- TODO : to_geojson avec jsonb_build_object ou ogr2ogr ou geopandas



----------------------------------------------------------------------
-- transaction, verrous, deadlocks
----------------------------------------------------------------------
			
show transaction isolation level; -- read committed

-- session 1
begin;

insert into communes_fr_pt (code_insee, nom_standard, dep_code)
values ('99999', 'New City', '99');

rollback; 
commit;

-- session 2
select code_insee, nom_standard, dep_code from communes_fr_pt where dep_code = '99';


-- session 3 : observation
select
	relation,
	pid,
	mode
from pg_locks
where relation = 'communes_fr_pt'::regclass;

-------------------------------------------
-- scenario 2


-- session 1
begin;
select code_insee, nom_standard, dep_code, population  from communes_fr_pt where dep_code = '99';
update communes_fr_pt set population = 9000 where code_insee = '99999';
update communes_fr_pt set population = 9000 where code_insee = '99998';

rollback; 
commit;

-- session 2
begin;
select code_insee, nom_standard, dep_code, population  from communes_fr_pt where dep_code = '99';
update communes_fr_pt set population = 8000 where code_insee = '99998';
update communes_fr_pt set population = 8000 where code_insee = '99999';

rollback; 
commit;

select code_insee, nom_standard, dep_code from communes_fr_pt where dep_code = '99';

-- => deeadlock détecté

-- solution 1 : pour ne jamais avoir de deadlock 
-- => definir un ordre dans la sequence de modif (PK, timestamp, ..)

-- solution 2 : select for update
begin;

select code_insee, nom_standard, dep_code, population  
from communes_fr_pt where code_insee in ('99998', '99999')
for update; -- reservation

update communes_fr_pt set population = 8000 where code_insee = '99998';
update communes_fr_pt set population = 8000 where code_insee = '99999';
commit;

-- plusieurs tables :
-- => ordonner tables puis select for update sur 1 table

-- Complément : liste des sessions => vue pg_stat_activity
-- pid : process enfant postgres en charge de la session cliente
-- datname, usename : db + user
-- application_name, client_addr, client_hostname
-- state, state_change : state + timestamp
-- query : current or last query
-- ...
select * from pg_stat_activity; 
-- extrait doc pour valeurs possibles state:
-- * starting: The backend is in initial startup. Client authentication is performed during this phase.
-- * active: The backend is executing a query.
-- * idle: The backend is waiting for a new client command.
-- * idle in transaction: The backend is in a transaction, but is not currently executing a query.
-- * idle in transaction (aborted): This state is similar to idle in transaction, except one of the statements in the transaction caused an error.
-- * fastpath function call: The backend is executing a fast-path function.
-- * disabled: This state is reported if track_activities is disabled in this backend.







