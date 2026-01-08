-- DBA
select * from pg_database;

create user dax with login password 'password';
create schema formation authorization dax;

select * from communes_fr limit 10;
show search_path; -- defaut: "$user",public
set search_path=formation; -- reglage session
show search_path; 
select * from communes_fr limit 10; --  "communes_fr" does not exist
select * from public.communes_fr limit 10; -- OK

-- reglage + permanent du search_path : database ou user
alter user dax set search_path = formation;


select * from pg_roles; -- role/user
select * from pg_user; -- "user" (with login)

-- blague
create role pau with login password 'password';

select * from pg_shadow; -- passwords + type cryptage (defaut: SCRAM-SHA-256)

vacuum full; -- tte la base (DBA)

create user lecteur with login password 'password';
alter user lecteur set search_path = formation;
grant usage on schema formation to lecteur;

-- grant 'shortcut' : table + vue
grant select on all tables in schema formation to lecteur;


create user manager with login password 'password';
alter user manager set search_path = formation;
grant usage on schema formation to manager;
grant select, insert, update, delete on formation.maires to manager;
grant all on sequence formation.maires_id_maire_seq to manager;

select * from pg_extension;
select * from pg_available_extensions;





