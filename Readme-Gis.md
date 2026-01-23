Voici un récapitulatif complet des types géométriques PostGIS, opérateurs et fonctions :

## **Types de Géométrie PostGIS**

### **Types de base**

```sql
-- Points
GEOMETRY(Point, 4326)           -- Point simple (longitude, latitude)
GEOMETRY(PointZ, 4326)          -- Point avec altitude
GEOMETRY(PointM, 4326)          -- Point avec mesure
GEOMETRY(PointZM, 4326)         -- Point avec altitude et mesure

-- Lignes
GEOMETRY(LineString, 4326)      -- Ligne simple
GEOMETRY(MultiLineString, 4326) -- Plusieurs lignes

-- Polygones
GEOMETRY(Polygon, 4326)         -- Polygone simple
GEOMETRY(MultiPolygon, 4326)    -- Plusieurs polygones

-- Collections
GEOMETRY(MultiPoint, 4326)      -- Plusieurs points
GEOMETRY(GeometryCollection, 4326) -- Collection mixte

-- Type générique
GEOMETRY(Geometry, 4326)        -- Accepte tout type
```

**Note :** `4326` = SRID (Spatial Reference System ID) pour WGS84 (GPS standard)

---

## **Opérateurs Spatiaux**

### **Opérateurs de relations topologiques**

```sql
-- Égalité exacte
geom1 = geom2                   -- Géométries identiques

-- Intersection de bounding box (index utilisé, RAPIDE)
geom1 && geom2                  -- Les bounding box se chevauchent

-- Contenance (bounding box)
geom1 @ geom2                   -- geom1 contenu dans bbox de geom2
geom1 ~ geom2                   -- geom1 contient bbox de geom2

-- Distance (bounding box)
geom1 <-> geom2                 -- Distance entre bounding box (pour ORDER BY)
```

---

## **Fonctions PostGIS**

### **1. Création de géométries**

```sql
-- Points
ST_MakePoint(longitude, latitude)
ST_MakePoint(2.3522, 48.8566)   -- Paris

-- Lignes
ST_MakeLine(point1, point2)
ST_MakeLine(ARRAY[point1, point2, point3])

-- Polygones
ST_MakePolygon(linestring)
ST_Polygon('POLYGON((0 0, 4 0, 4 4, 0 4, 0 0))', 4326)

-- À partir de texte WKT
ST_GeomFromText('POINT(2.3522 48.8566)', 4326)
ST_GeomFromText('LINESTRING(0 0, 1 1, 2 2)', 4326)

-- À partir de GeoJSON
ST_GeomFromGeoJSON('{"type":"Point","coordinates":[2.3522,48.8566]}')
```

### **2. Relations spatiales (précises)**

```sql
-- Contenance
ST_Contains(geom1, geom2)       -- geom1 contient entièrement geom2
ST_Within(geom1, geom2)         -- geom1 est entièrement dans geom2

-- Intersection
ST_Intersects(geom1, geom2)     -- Les géométries se touchent ou se chevauchent
ST_Overlaps(geom1, geom2)       -- Chevauchement partiel
ST_Crosses(geom1, geom2)        -- Se croisent

-- Proximité
ST_Touches(geom1, geom2)        -- Se touchent aux limites
ST_Disjoint(geom1, geom2)       -- Ne se touchent pas du tout

-- Couverture
ST_Covers(geom1, geom2)         -- geom1 couvre geom2 (inclut limites)
ST_CoveredBy(geom1, geom2)      -- geom1 couvert par geom2
```

### **3. Mesures et distances**

```sql
-- Distance
ST_Distance(geom1, geom2)                -- Distance en unités du SRID
ST_Distance(geom1::geography, geom2::geography) -- Distance en mètres

-- Distance avec seuil (optimisé)
ST_DWithin(geom1, geom2, distance)       -- TRUE si distance < seuil
ST_DWithin(geom::geography, point::geography, 1000) -- Dans 1km

-- Longueur
ST_Length(linestring)                    -- Longueur d'une ligne
ST_Length(linestring::geography)         -- Longueur en mètres

-- Surface
ST_Area(polygon)                         -- Surface d'un polygone
ST_Area(polygon::geography)              -- Surface en m²

-- Périmètre
ST_Perimeter(polygon)                    -- Périmètre
```

### **4. Transformations géométriques**

```sql
-- Buffer (zone tampon)
ST_Buffer(geom, distance)                -- Agrandit la géométrie
ST_Buffer(point::geography, 1000)        -- Cercle de 1km autour du point

-- Centroïde
ST_Centroid(geom)                        -- Centre géométrique

-- Enveloppe
ST_Envelope(geom)                        -- Rectangle englobant (bbox)
ST_ConvexHull(geom)                      -- Enveloppe convexe

-- Simplification
ST_Simplify(geom, tolerance)             -- Simplifie (Douglas-Peucker)
ST_SimplifyPreserveTopology(geom, tolerance)

-- Union
ST_Union(geom1, geom2)                   -- Fusionne géométries
ST_Union(geom)                           -- Agrégation (GROUP BY)

-- Différence
ST_Difference(geom1, geom2)              -- geom1 moins geom2
ST_Intersection(geom1, geom2)            -- Partie commune
ST_SymDifference(geom1, geom2)           -- XOR spatial

-- Découpage
ST_Split(geom, blade)                    -- Découpe geom par blade
```

### **5. Propriétés et informations**

```sql
-- Type
ST_GeometryType(geom)                    -- 'ST_Point', 'ST_Polygon'...
ST_Dimension(geom)                       -- 0=point, 1=ligne, 2=surface

-- SRID
ST_SRID(geom)                            -- Obtenir le SRID
ST_SetSRID(geom, 4326)                   -- Définir le SRID

-- Coordonnées
ST_X(point)                              -- Longitude
ST_Y(point)                              -- Latitude
ST_Z(point)                              -- Altitude

-- Nombre d'éléments
ST_NumGeometries(multi_geom)             -- Nombre de géométries
ST_NumPoints(linestring)                 -- Nombre de points

-- Validité
ST_IsValid(geom)                         -- Géométrie valide?
ST_IsSimple(geom)                        -- Géométrie simple?
ST_IsEmpty(geom)                         -- Géométrie vide?
```

### **6. Extraction et conversion**

```sql
-- Extraction
ST_StartPoint(linestring)                -- Premier point
ST_EndPoint(linestring)                  -- Dernier point
ST_PointN(linestring, n)                 -- N-ième point
ST_GeometryN(multi_geom, n)              -- N-ième géométrie

-- Conversion de format
ST_AsText(geom)                          -- Format WKT (texte)
ST_AsGeoJSON(geom)                       -- Format GeoJSON
ST_AsKML(geom)                           -- Format KML (Google Earth)
ST_AsGML(geom)                           -- Format GML
ST_AsBinary(geom)                        -- Format WKB (binaire)

-- Projection
ST_Transform(geom, target_srid)          -- Change de système de coordonnées
ST_Transform(geom, 3857)                 -- Vers Web Mercator
```

---

## **Exemples Pratiques**

### **Trouver tous les points dans un rayon**

```sql
SELECT * FROM lieux
WHERE ST_DWithin(
    geom::geography,
    ST_MakePoint(2.3522, 48.8566)::geography,
    5000  -- 5km
);
```

### **Trouver les polygones qui contiennent un point**

```sql
SELECT * FROM zones
WHERE ST_Contains(geom, ST_MakePoint(2.3522, 48.8566));
```

### **Calculer la distance entre deux villes**

```sql
SELECT 
    v1.nom,
    v2.nom,
    ST_Distance(v1.geom::geography, v2.geom::geography) / 1000 AS distance_km
FROM villes v1, villes v2
WHERE v1.id = 1 AND v2.id = 2;
```

### **Créer une zone tampon de 500m**

```sql
UPDATE batiments
SET zone_influence = ST_Buffer(geom::geography, 500)::geometry
WHERE id = 123;
```

### **Trouver les 10 restaurants les plus proches**

```sql
SELECT nom, 
       ST_Distance(geom::geography, ST_MakePoint(2.3522, 48.8566)::geography) AS distance
FROM restaurants
ORDER BY geom <-> ST_MakePoint(2.3522, 48.8566)::geometry
LIMIT 10;
```

### **Calculer la surface d'un polygone**

```sql
SELECT 
    nom,
    ST_Area(geom::geography) / 10000 AS superficie_hectares
FROM parcelles;
```

---

## **Différence GEOMETRY vs GEOGRAPHY**

```sql
-- GEOMETRY : Calculs plans (rapide mais imprécis sur grandes distances)
ST_Distance(geom1, geom2)  -- Résultat en degrés (inutile!)

-- GEOGRAPHY : Calculs sphériques (précis, résultat en mètres)
ST_Distance(geom::geography, point::geography)  -- Résultat en mètres
```

**Recommandation :** Utilisez `::geography` pour les calculs de distance et surface réels !

---

Ce récapitulatif couvre les fonctions les plus utilisées. PostGIS en compte plus de 400 au total ! 🗺️