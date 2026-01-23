-- Export au format TSV (CSV delimiter TAB)
-- psql -U dax -d dbcity -f day3-export-tsv.sql
\copy (select nom, st_astext(geom) as geom from commune_shp where insee_dep = '40') TO 'communes_40.tsv' with (FORMAT csv, delimiter E'\t', encoding 'UTF8', header)
