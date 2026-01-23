
-- extensions activées dans la base courante
select * from pg_extension; 

-- extensions activées dans la base courante
select * from pg_available_extensions
order by name;

create extension pg_stat_statements;

-- + postgresql.conf : 
-- shared_preload_libraries = 'pg_stat_statements'         # (change requires restart)

select * from pg_stat_statements;