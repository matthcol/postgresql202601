-- prealable : avoir l'extension postgis disponible
-- par exemple via le manager de la distribution
-- Ex:  apt install postgresql-18-postgis-3 postgresql-18-postgis-3-scripts

-- nouvelle base avec template par defaut
select * from pg_extension; -- plpgsql

create extension postgis;
create extension postgis_topology;

select * from pg_extension;