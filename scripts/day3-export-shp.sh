#!/bin/bash

# Tool : pgsql2shp (paquet debian postgis)
pgsql2shp -u dax -f communes40.shp dbcity "select insee_com, nom, geom from commune_shp where insee_dep = '40'"
