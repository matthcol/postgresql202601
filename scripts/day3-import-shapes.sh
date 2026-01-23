#!/bin/bash

# NB : se placer dans le répertoire contenant les fichiers *.shp
#      adapter noms des tables (avec/sans schema vs search_path) et informations de connexion

shp2pgsql -I -s 2154 DEPARTEMENT.shp departement_shp | psql -U dax -d dbcity
shp2pgsql -I -s 2154 COMMUNE.shp commune_shp | psql -U dax -d dbcity
