select code_insee, nom_standard, dep_code from communes_fr;
select code_insee, nom_standard, dep_code from v_communes_40;
select * from maires;

-- Erreur sur schema si pas privilege USAGE
-- Erreur sur table si pas privilege SELECT sur l'objet