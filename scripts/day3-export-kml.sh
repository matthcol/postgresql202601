#!/bin/bash

# Tool: ogr2ogr (comes with gdal)
# champs prevus en 2D : -dsco NameField et -dsco DescriptionField
# le reste part en extended data
# password (en fonction du pghba.conf) password=xxx ou fichier .pgpass ou env var PGPASSWORD

ogr2ogr -f "KML" communes40.kml \
    -dsco NameField=nom \
    -nln commune \
    PG:"host=localhost dbname=dbcity user=dax" \
    -sql "select insee_com, nom, population, geom from commune_shp where insee_dep = '40'"