#!/bin/bash

# Tool: ogr2ogr (comes with gdal)
ogr2ogr -f "GeoJSON" communes40.geojson \
    PG:"host=localhost dbname=dbcity user=dax" \
    -sql "select insee_com, nom, geom from commune_shp where insee_dep = '40'"
    