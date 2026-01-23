# PostgreSQL

## Dumps
Format SQL
```
pg_dump -U dax -d dbcity -n formation -f formation.dump
psql -U postgres -d dbcity -f formation.dump
```

## Psql

Shortcuts:

```
\d : liste des tables, vues, sequences
\d ma_table : description table
\l : liste des base
\x : swith affichage horizontal/vertical
```

## Données Administrative IGN
https://geoservices.ign.fr/telechargement-api/ADMIN-EXPRESS

## Import/Export PostGIS
- paquet debian postgis :
```
/usr/bin/pgsql2shp
/usr/bin/pgtopo_export
/usr/bin/pgtopo_import
/usr/bin/postgis
/usr/bin/postgis_restore
/usr/bin/raster2pgsql
/usr/bin/shp2pgsql
```

- exemple import (-I : create indexes, -s : set SRID):
```
shp2pgsql -I -s 2154 DEPARTEMENT.shp departement_shp | psql -U dax -d dbcity
shp2pgsql -I -s 2154 COMMUNE.shp commune_shp | psql -U dax -d dbcity
```

TODO: export pgsql2shp

## Import/Export copy
COPY sql ou \copy psql

## Export ogr2ogr

## Export geopandas