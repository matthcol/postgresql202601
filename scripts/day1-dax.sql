-- user dax proprietaire de la data (schema formation)

create view v_communes_40 as
select * from communes_fr
where dep_code = '40'
;

select 
	1 + 3,
	1.2 + 1.5,
	1.2::real + 1.5::real,
	current_timestamp + '1 day'::interval;

alter table communes_fr
add constraint pk_communes_fr primary key(code_insee);
-- primary key => unique => create index unique

select * from pg_indexes where schemaname = 'formation';

-- index explicite
create index idx_communes_cp on communes_fr (code_postal);

-- stockage data
select oid, relname, relkind
from pg_class 
where relnamespace = 19897; -- schema formation oid: 19897

-- relkind: 
-- r = ordinary table, i = index, S = sequence, t = TOAST table, v = view, m = materialized view, c = composite type, f = foreign table, p = partitioned table, I = partitioned index

select current_user;
show search_path;  -- formation

create table maires(
	id_maire serial constraint pk_maires primary key,
	nom varchar(50) not null,
	prenom varchar(50)
);

-- smallserial = smallint + sequence + default
-- serial = int + sequence + default
-- bigserial = bigint + sequence + default

select 
	2^15 - 1,
	2^31 - 1,
	2^63 - 1
;

select oid, relname, relkind
from pg_class 
where relnamespace = 19897; 

-- table communes_fr : oid = 19898

select * from pg_database;

insert into maires (nom, prenom)
values 
	('Doe', 'John'),
	('Doe', 'Jane'),
	('Doe', NULL)
;

delete from communes_fr
where dep_code in ('2A', '2B');

delete from communes_fr
where dep_code::int % 2 = 1;

select count(*) from communes_fr;

vacuum communes_fr; -- menage simple (recensement)
vacuum full communes_fr; --menage complet (defragmentation)



select 
	oid, 
	relname, 
	relkind, 
	relfilenode -- fichier (change à chaque vacuum full)
from pg_class 
where relnamespace = 19897; 

select currval('maires_id_maire_seq');
select nextval('maires_id_maire_seq');
select currval('maires_id_maire_seq');

select setval('maires_id_maire_seq', 10);
select nextval('maires_id_maire_seq');

select setval('maires_id_maire_seq', max(id_maire)) from maires;
select nextval('maires_id_maire_seq');







	