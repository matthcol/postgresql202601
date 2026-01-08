select * from maires;
select * from maires;
insert into maires (nom, prenom) values ('Mayor', 'Super'); --  nextval implicite sur la sequence maires_id_maire_seq
select currval('maires_id_maire_seq');
select nextval('maires_id_maire_seq');

