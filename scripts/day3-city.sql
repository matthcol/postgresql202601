select *
from communes_fr_pt
where latitude_centre is null;

-- utilise indexes sur:
-- * code_postal : BTREE
-- * codes_postaux : GIN
select *
from communes_fr_pt
where 
	code_postal = '31200'
	or ARRAY['31200']::char(5)[] <@ codes_postaux
;

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
-- coordonnées en Lambert 93 (2154) : stocker et/ou indexer

-- sol 1 : stocker

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
	
	


