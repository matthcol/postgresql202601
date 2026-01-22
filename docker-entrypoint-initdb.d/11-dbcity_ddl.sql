
--
-- Name: communes_fr_pt; Type: TABLE; Schema: formation; Owner: dax
--

CREATE TABLE formation.communes_fr_pt (
    code_insee character(5) NOT NULL,
    nom_standard character varying(50) NOT NULL,
    nom_sans_pronom character varying(50),
    nom_a character varying(50),
    nom_de character varying(50),
    nom_sans_accent character varying(50),
    nom_standard_majuscule character varying(50),
    typecom character(3),
    typecom_texte character(7),
    reg_code character(2),
    reg_nom character varying(30),
    dep_code character varying(3),
    dep_nom character varying(30),
    canton_code character(5),
    canton_nom character varying(40),
    epci_code character(9),
    epci_nom character varying(60),
    academie_code character(2),
    academie_nom character varying(20),
    code_postal character(5),
    codes_postaux character(5)[],
    zone_emploi character(5),
    code_insee_centre_zone_emploi character(5),
    code_unite_urbaine character(5),
    nom_unite_urbaine character varying(60),
    taille_unite_urbaine smallint,
    type_commune_unite_urbaine character varying(20),
    statut_commune_unite_urbaine character(1),
    population integer,
    superficie_hectare integer,
    superficie_km2 integer,
    densite integer,
    altitude_moyenne smallint,
    altitude_minimale smallint,
    altitude_maximale smallint,
    latitude_mairie real,
    longitude_mairie real,
    latitude_centre real,
    longitude_centre real,
    grille_densite smallint,
    grille_densite_texte character varying(30),
    niveau_equipements_services smallint,
    niveau_equipements_services_texte character varying(60),
    gentile text,
    url_wikipedia text,
    url_villedereve text,
    geometry public.geometry(Point,4326)
);


ALTER TABLE formation.communes_fr_pt OWNER TO dax;

-- Primary key

alter table formation.communes_fr_pt
add constraint pk_communes_fr_pt primary key(code_insee);


--
-- autres indexes
--

create index idx_communes_fr_pt_cp on formation.communes_fr_pt (code_postal);
create index idx_communes_fr_pt_cpx on formation.communes_fr_pt using GIN(codes_postaux);
CREATE INDEX idx_communes_fr_pt_geom_w84 ON formation.communes_fr_pt USING GIST(geometry);
create index idx_communes_fr_pt_population on formation.communes_fr_pt(population);

