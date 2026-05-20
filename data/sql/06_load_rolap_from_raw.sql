-- =============================================================================
-- Script: 06_load_rolap_from_raw.sql
-- Purpose: Populate db_rolap directly from raw Access data loaded by mdb-loader
--          into the `database` MySQL schema.
-- Run order: After 05_rolap_warehouse.sql
-- =============================================================================

USE db_rolap;

-- Align db_rolap collation with MySQL 9 default (utf8mb4_0900_ai_ci)
-- so cross-schema string comparisons with `database.*` don't fail.
ALTER DATABASE db_rolap DEFAULT COLLATE utf8mb4_0900_ai_ci;
ALTER TABLE dim_produit CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
ALTER TABLE dim_client  CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
ALTER TABLE dim_magasin CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
ALTER TABLE dim_temps   CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

SET @ref_date = '2010-01-01';

-- Allow large GROUP_CONCAT for dedup queries
SET SESSION group_concat_max_len = 1000000;

-- ===========================================================================
-- TRUNCATE (fresh load)
-- ===========================================================================
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE agg_locations_mois_produit_magasin;
TRUNCATE TABLE agg_ventes_mois_produit;
TRUNCATE TABLE agg_ventes_mois_magasin;
TRUNCATE TABLE fait_locations;
TRUNCATE TABLE fait_ventes;
TRUNCATE TABLE dim_produit;
TRUNCATE TABLE dim_client;
SET FOREIGN_KEY_CHECKS = 1;
-- dim_magasin and dim_temps already populated: do not touch

-- ===========================================================================
-- STEP 1 — dim_produit
-- ===========================================================================

-- 1a. Films from MetroStarlet (primary source: most complete metadata)
INSERT INTO dim_produit (titre, type, sous_type, film_id)
SELECT DISTINCT
  REGEXP_REPLACE(movie_title, '^T', '')  AS titre,
  'film'                                 AS type,
  'movie'                                AS sous_type,
  movieid                                AS film_id
FROM database.metrostarlet_movie
WHERE movie_title IS NOT NULL
  AND TRIM(REGEXP_REPLACE(movie_title, '^T', '')) != '';

-- 1b. Films from BuckBoaster not already present (match on normalized title)
INSERT INTO dim_produit (titre, type, sous_type, film_id)
SELECT DISTINCT
  REGEXP_REPLACE(bb.movie_title, '^T', '') AS titre,
  'film'                                   AS type,
  'movie'                                  AS sous_type,
  NULL                                     AS film_id
FROM database.buckboaster_movie bb
WHERE bb.movie_title IS NOT NULL
  AND TRIM(REGEXP_REPLACE(bb.movie_title, '^T', '')) != ''
  AND NOT EXISTS (
    SELECT 1 FROM dim_produit dp
    WHERE dp.type = 'film'
      AND REGEXP_REPLACE(LOWER(dp.titre), '[^a-z0-9]', '') =
          REGEXP_REPLACE(LOWER(REGEXP_REPLACE(bb.movie_title, '^T', '')), '[^a-z0-9]', '')
  );

-- 1c. Gadgets from BuckBoaster
INSERT INTO dim_produit (titre, type, sous_type, film_id)
SELECT DISTINCT
  REGEXP_REPLACE(title, '^T', '') AS titre,
  'gadget'                        AS type,
  REGEXP_REPLACE(type, '^T', '') AS sous_type,
  NULL                            AS film_id
FROM database.buckboaster_gadget
WHERE title IS NOT NULL;

-- 1d. Gadgets from MovieMegaMart not already present
INSERT INTO dim_produit (titre, type, sous_type, film_id)
SELECT DISTINCT
  REGEXP_REPLACE(gadget_title, '^T', '') AS titre,
  'gadget'                               AS type,
  REGEXP_REPLACE(gadget_type, '^T', '')  AS sous_type,
  NULL                                   AS film_id
FROM database.moviemegamart_gadgetsales
WHERE gadget_title IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM dim_produit dp
    WHERE dp.type = 'gadget'
      AND LOWER(dp.titre) = LOWER(REGEXP_REPLACE(gadget_title, '^T', ''))
  );

-- ===========================================================================
-- STEP 2 — dim_client
-- ===========================================================================

-- 2a. BuckBoaster clients (dedup on prenom + nom + date_naissance)
INSERT INTO dim_client (prenom, nom, date_naissance, age, tranche_age, genre, magasin_id)
SELECT
  REGEXP_REPLACE(MIN(firstname), '^T', '')      AS prenom,
  REGEXP_REPLACE(MIN(lastname), '^T', '')       AS nom,
  DATE(MIN(dob))                                AS date_naissance,
  GREATEST(0, TIMESTAMPDIFF(YEAR, DATE(MIN(dob)), @ref_date)) AS age,
  CASE
    WHEN GREATEST(0, TIMESTAMPDIFF(YEAR, DATE(MIN(dob)), @ref_date)) < 25  THEN '<25'
    WHEN GREATEST(0, TIMESTAMPDIFF(YEAR, DATE(MIN(dob)), @ref_date)) < 40  THEN '25-40'
    WHEN GREATEST(0, TIMESTAMPDIFF(YEAR, DATE(MIN(dob)), @ref_date)) < 60  THEN '40-60'
    ELSE '>60'
  END                                           AS tranche_age,
  CASE WHEN MIN(sex) LIKE '%Female%' THEN 'F' ELSE 'M' END AS genre,
  1                                             AS magasin_id
FROM database.buckboaster_customer
WHERE dob IS NOT NULL AND firstname IS NOT NULL AND lastname IS NOT NULL
GROUP BY
  LOWER(REGEXP_REPLACE(firstname, '^T', '')),
  LOWER(REGEXP_REPLACE(lastname, '^T', '')),
  DATE(dob);

-- 2b. MetroStarlet clients
INSERT INTO dim_client (prenom, nom, date_naissance, age, tranche_age, genre, magasin_id)
SELECT
  REGEXP_REPLACE(name, '^T', '') AS prenom,
  REGEXP_REPLACE(surname, '^T', '') AS nom,
  CASE
    WHEN birthday IS NOT NULL
         AND REGEXP_REPLACE(birthday, '^T', '') REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}'
    THEN DATE(STR_TO_DATE(REGEXP_REPLACE(birthday, '^T', ''), '%Y-%m-%d'))
    ELSE NULL
  END AS date_naissance,
  CASE
    WHEN birthday IS NOT NULL
         AND REGEXP_REPLACE(birthday, '^T', '') REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}'
    THEN GREATEST(0, TIMESTAMPDIFF(YEAR,
           DATE(STR_TO_DATE(REGEXP_REPLACE(birthday, '^T', ''), '%Y-%m-%d')),
           @ref_date))
    ELSE NULL
  END AS age,
  CASE
    WHEN birthday IS NOT NULL
         AND REGEXP_REPLACE(birthday, '^T', '') REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}'
    THEN
      CASE
        WHEN GREATEST(0, TIMESTAMPDIFF(YEAR,
               DATE(STR_TO_DATE(REGEXP_REPLACE(birthday, '^T', ''), '%Y-%m-%d')),
               @ref_date)) < 25  THEN '<25'
        WHEN GREATEST(0, TIMESTAMPDIFF(YEAR,
               DATE(STR_TO_DATE(REGEXP_REPLACE(birthday, '^T', ''), '%Y-%m-%d')),
               @ref_date)) < 40  THEN '25-40'
        WHEN GREATEST(0, TIMESTAMPDIFF(YEAR,
               DATE(STR_TO_DATE(REGEXP_REPLACE(birthday, '^T', ''), '%Y-%m-%d')),
               @ref_date)) < 60  THEN '40-60'
        ELSE '>60'
      END
    ELSE 'Inconnu'
  END AS tranche_age,
  CASE WHEN gender = 'M' THEN 'M' WHEN gender = 'F' THEN 'F' ELSE NULL END AS genre,
  2 AS magasin_id
FROM database.metrostarlet_customer
WHERE name IS NOT NULL;

-- 2c. MovieMegaMart clients (reconstructed + dedup on cust_name, birthdate)
INSERT INTO dim_client (prenom, nom, date_naissance, age, tranche_age, genre, magasin_id)
SELECT DISTINCT
  SUBSTRING_INDEX(REGEXP_REPLACE(cust_name, '^T', ''), ' ', 1)  AS prenom,
  SUBSTRING_INDEX(REGEXP_REPLACE(cust_name, '^T', ''), ' ', -1) AS nom,
  DATE(birthdate)                                                AS date_naissance,
  GREATEST(0, TIMESTAMPDIFF(YEAR, DATE(birthdate), @ref_date))  AS age,
  CASE
    WHEN GREATEST(0, TIMESTAMPDIFF(YEAR, DATE(birthdate), @ref_date)) < 25  THEN '<25'
    WHEN GREATEST(0, TIMESTAMPDIFF(YEAR, DATE(birthdate), @ref_date)) < 40  THEN '25-40'
    WHEN GREATEST(0, TIMESTAMPDIFF(YEAR, DATE(birthdate), @ref_date)) < 60  THEN '40-60'
    ELSE '>60'
  END                                                            AS tranche_age,
  CASE WHEN sex_male = 1 THEN 'M' ELSE 'F' END                  AS genre,
  3                                                              AS magasin_id
FROM (
  SELECT cust_name, sex_male, birthdate FROM database.moviemegamart_movierentals WHERE cust_name IS NOT NULL AND birthdate IS NOT NULL
  UNION
  SELECT cust_name, sex_male, birthdate FROM database.moviemegamart_moviesales   WHERE cust_name IS NOT NULL AND birthdate IS NOT NULL
  UNION
  SELECT cust_name, sex_male, birthdate FROM database.moviemegamart_gadgetsales  WHERE cust_name IS NOT NULL AND birthdate IS NOT NULL
) all_mmm;

-- ===========================================================================
-- STEP 3 — fait_ventes
-- ===========================================================================

-- 3a. BuckBoaster film sales (sale_item WHERE sale_price IS NOT NULL)
INSERT INTO fait_ventes (temps_id, magasin_id, client_id, produit_id, annee,
                         ca_ventes, prix_inventaire_total, nb_ventes, est_neuf)
SELECT
  dt.temps_id,
  1                         AS magasin_id,
  dc.client_id,
  dp.produit_id,
  YEAR(si.sale_date)        AS annee,
  si.sale_price             AS ca_ventes,
  si.inventory_price        AS prix_inventaire_total,
  1                         AS nb_ventes,
  0                         AS est_neuf
FROM database.buckboaster_sale_item si
INNER JOIN database.buckboaster_movie    bm ON bm.movie_id = si.refers_to
INNER JOIN database.buckboaster_customer bc ON bc.code = si.cust_id
INNER JOIN dim_temps dt
  ON dt.date_complete = DATE(si.sale_date)
INNER JOIN dim_produit dp
  ON dp.type = 'film'
  AND REGEXP_REPLACE(LOWER(dp.titre), '[^a-z0-9]', '') =
      REGEXP_REPLACE(LOWER(REGEXP_REPLACE(bm.movie_title, '^T', '')), '[^a-z0-9]', '')
INNER JOIN dim_client dc
  ON dc.magasin_id = 1
  AND LOWER(dc.prenom) = LOWER(REGEXP_REPLACE(bc.firstname, '^T', ''))
  AND LOWER(dc.nom)   = LOWER(REGEXP_REPLACE(bc.lastname,  '^T', ''))
  AND dc.date_naissance = DATE(bc.dob)
WHERE si.sale_price IS NOT NULL
  AND si.sale_date IS NOT NULL;

-- 3b. BuckBoaster gadget sales
INSERT INTO fait_ventes (temps_id, magasin_id, client_id, produit_id, annee,
                         ca_ventes, prix_inventaire_total, nb_ventes, est_neuf)
SELECT
  dt.temps_id,
  1                         AS magasin_id,
  dc.client_id,
  dp.produit_id,
  YEAR(g.sale_date)         AS annee,
  g.sale_price              AS ca_ventes,
  g.price                   AS prix_inventaire_total,
  1                         AS nb_ventes,
  0                         AS est_neuf
FROM database.buckboaster_gadget g
INNER JOIN database.buckboaster_customer bc ON bc.code = g.cust_id
INNER JOIN dim_temps dt ON dt.date_complete = DATE(g.sale_date)
INNER JOIN dim_produit dp
  ON dp.type = 'gadget'
  AND LOWER(dp.titre) = LOWER(REGEXP_REPLACE(g.title, '^T', ''))
INNER JOIN dim_client dc
  ON dc.magasin_id = 1
  AND LOWER(dc.prenom) = LOWER(REGEXP_REPLACE(bc.firstname, '^T', ''))
  AND LOWER(dc.nom)   = LOWER(REGEXP_REPLACE(bc.lastname,  '^T', ''))
  AND dc.date_naissance = DATE(bc.dob)
WHERE g.sale_date IS NOT NULL
  AND g.sale_price IS NOT NULL;

-- 3c. MetroStarlet film sales (copy_for_sale)
INSERT INTO fait_ventes (temps_id, magasin_id, client_id, produit_id, annee,
                         ca_ventes, prix_inventaire_total, nb_ventes, est_neuf)
SELECT
  dt.temps_id,
  2                         AS magasin_id,
  dc.client_id,
  dp.produit_id,
  YEAR(cfs.sale_date)       AS annee,
  cfs.sale_price            AS ca_ventes,
  NULL                      AS prix_inventaire_total,
  1                         AS nb_ventes,
  cfs.is_new                AS est_neuf
FROM database.metrostarlet_copy_for_sale cfs
INNER JOIN database.metrostarlet_movie    mm ON mm.movieid = cfs.movie_id
INNER JOIN database.metrostarlet_customer mc ON mc.code = cfs.soldto
INNER JOIN dim_temps dt ON dt.date_complete = DATE(cfs.sale_date)
INNER JOIN dim_produit dp ON dp.type = 'film' AND dp.film_id = mm.movieid
INNER JOIN dim_client dc
  ON dc.magasin_id = 2
  AND LOWER(dc.prenom) = LOWER(REGEXP_REPLACE(mc.name,    '^T', ''))
  AND LOWER(dc.nom)   = LOWER(REGEXP_REPLACE(mc.surname,  '^T', ''))
WHERE cfs.sale_date IS NOT NULL
  AND cfs.sale_price IS NOT NULL;

-- 3d. MovieMegaMart film sales
INSERT INTO fait_ventes (temps_id, magasin_id, client_id, produit_id, annee,
                         ca_ventes, prix_inventaire_total, nb_ventes, est_neuf)
SELECT
  dt.temps_id,
  3                         AS magasin_id,
  dc.client_id,
  dp.produit_id,
  YEAR(ms.sale_date)        AS annee,
  ms.price_sale             AS ca_ventes,
  NULL                      AS prix_inventaire_total,
  1                         AS nb_ventes,
  0                         AS est_neuf
FROM database.moviemegamart_moviesales ms
INNER JOIN dim_temps dt ON dt.date_complete = DATE(ms.sale_date)
INNER JOIN dim_produit dp ON dp.type = 'film' AND dp.film_id = ms.movie_id
INNER JOIN dim_client dc
  ON dc.magasin_id = 3
  AND LOWER(dc.prenom) = LOWER(SUBSTRING_INDEX(REGEXP_REPLACE(ms.cust_name, '^T', ''), ' ', 1))
  AND LOWER(dc.nom)   = LOWER(SUBSTRING_INDEX(REGEXP_REPLACE(ms.cust_name, '^T', ''), ' ', -1))
  AND dc.date_naissance = DATE(ms.birthdate)
WHERE ms.sale_date IS NOT NULL
  AND ms.price_sale IS NOT NULL;

-- 3e. MovieMegaMart gadget sales
INSERT INTO fait_ventes (temps_id, magasin_id, client_id, produit_id, annee,
                         ca_ventes, prix_inventaire_total, nb_ventes, est_neuf)
SELECT
  dt.temps_id,
  3                         AS magasin_id,
  dc.client_id,
  dp.produit_id,
  YEAR(gs.sale_date)        AS annee,
  gs.price_sale             AS ca_ventes,
  gs.inv_price              AS prix_inventaire_total,
  1                         AS nb_ventes,
  0                         AS est_neuf
FROM database.moviemegamart_gadgetsales gs
INNER JOIN dim_temps dt ON dt.date_complete = DATE(gs.sale_date)
INNER JOIN dim_produit dp
  ON dp.type = 'gadget'
  AND LOWER(dp.titre) = LOWER(REGEXP_REPLACE(gs.gadget_title, '^T', ''))
INNER JOIN dim_client dc
  ON dc.magasin_id = 3
  AND LOWER(dc.prenom) = LOWER(SUBSTRING_INDEX(REGEXP_REPLACE(gs.cust_name, '^T', ''), ' ', 1))
  AND LOWER(dc.nom)   = LOWER(SUBSTRING_INDEX(REGEXP_REPLACE(gs.cust_name, '^T', ''), ' ', -1))
  AND dc.date_naissance = DATE(gs.birthdate)
WHERE gs.sale_date IS NOT NULL;

-- ===========================================================================
-- STEP 4 — fait_locations
-- Source tables have no indexes (mdb-loader imports raw); add them for speed.
-- ADD INDEX IF NOT EXISTS was added in MySQL 8.0.29; use a stored procedure
-- with an INFORMATION_SCHEMA check to stay compatible with earlier releases.
-- ===========================================================================

DROP PROCEDURE IF EXISTS _add_src_index;
CREATE PROCEDURE _add_src_index(
  IN p_schema VARCHAR(64),
  IN p_table  VARCHAR(64),
  IN p_index  VARCHAR(64),
  IN p_col    VARCHAR(64)
)
BEGIN
  DECLARE idx_count INT DEFAULT 0;
  SELECT COUNT(*) INTO idx_count
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = p_schema
    AND TABLE_NAME   = p_table
    AND INDEX_NAME   = p_index;
  IF idx_count = 0 THEN
    SET @_add_idx_sql = CONCAT(
      'ALTER TABLE `', p_schema, '`.`', p_table, '` ADD INDEX ', p_index, ' (`', p_col, '`)'
    );
    PREPARE _add_idx_stmt FROM @_add_idx_sql;
    EXECUTE _add_idx_stmt;
    DEALLOCATE PREPARE _add_idx_stmt;
  END IF;
END;
CALL _add_src_index('database', 'metrostarlet_copy_for_rent',  'idx_id',       'id');
CALL _add_src_index('database', 'metrostarlet_copy_for_rent',  'idx_movie_id', 'movie_id');
CALL _add_src_index('database', 'metrostarlet_copy_rented_to', 'idx_copy_id',  'copy_id');
CALL _add_src_index('database', 'metrostarlet_copy_rented_to', 'idx_cust_id',  'cust_id');
CALL _add_src_index('database', 'moviemegamart_movierentals',  'idx_movie_id', 'movie_id');
DROP PROCEDURE IF EXISTS _add_src_index;

-- 4a. MetroStarlet rentals — use pre-normalized temp tables to avoid
--     non-indexable REGEXP_REPLACE() calls in the JOIN condition.
DROP TEMPORARY TABLE IF EXISTS tmp_mc_ms;
CREATE TEMPORARY TABLE tmp_mc_ms (
  code     BIGINT,
  prenom_n VARCHAR(200),
  nom_n    VARCHAR(200),
  INDEX idx_code (code),
  INDEX idx_name (prenom_n(50), nom_n(50))
)
SELECT code,
       LOWER(REGEXP_REPLACE(name,    '^T', '')) AS prenom_n,
       LOWER(REGEXP_REPLACE(surname, '^T', '')) AS nom_n
FROM database.metrostarlet_customer;

DROP TEMPORARY TABLE IF EXISTS tmp_dc_ms;
CREATE TEMPORARY TABLE tmp_dc_ms (
  client_id INT NOT NULL,
  prenom_n  VARCHAR(200),
  nom_n     VARCHAR(200),
  INDEX idx_name (prenom_n(50), nom_n(50))
)
SELECT client_id, LOWER(prenom) AS prenom_n, LOWER(nom) AS nom_n
FROM dim_client WHERE magasin_id = 2;

INSERT INTO fait_locations (temps_id, magasin_id, client_id, produit_id, annee,
                            ca_locations, nb_locations, nb_jours_total)
SELECT
  dt.temps_id,
  2                                                            AS magasin_id,
  dc.client_id,
  dp.produit_id,
  YEAR(cr.from_date)                                          AS annee,
  cr.price_day * GREATEST(1, DATEDIFF(cr.to_date, cr.from_date)) AS ca_locations,
  1                                                            AS nb_locations,
  GREATEST(1, DATEDIFF(cr.to_date, cr.from_date))             AS nb_jours_total
FROM database.metrostarlet_copy_rented_to cr
INNER JOIN database.metrostarlet_copy_for_rent cfr ON cfr.id = cr.copy_id
INNER JOIN database.metrostarlet_movie         mm  ON mm.movieid = cfr.movie_id
INNER JOIN tmp_mc_ms mc  ON mc.code = cr.cust_id
INNER JOIN dim_temps dt  ON dt.date_complete = DATE(cr.from_date)
INNER JOIN dim_produit dp ON dp.type = 'film' AND dp.film_id = mm.movieid
INNER JOIN tmp_dc_ms dc  ON dc.prenom_n = mc.prenom_n AND dc.nom_n = mc.nom_n
WHERE cr.from_date IS NOT NULL
  AND cr.to_date IS NOT NULL
  AND cr.to_date > cr.from_date;

-- 4b. MovieMegaMart rentals
DROP TEMPORARY TABLE IF EXISTS tmp_dc_mmm;
CREATE TEMPORARY TABLE tmp_dc_mmm (
  client_id INT NOT NULL,
  prenom_n  VARCHAR(200),
  nom_n     VARCHAR(200),
  dob       DATE,
  INDEX idx_name_dob (prenom_n(50), nom_n(50), dob)
)
SELECT client_id, LOWER(prenom) AS prenom_n, LOWER(nom) AS nom_n, date_naissance AS dob
FROM dim_client WHERE magasin_id = 3;

INSERT INTO fait_locations (temps_id, magasin_id, client_id, produit_id, annee,
                            ca_locations, nb_locations, nb_jours_total)
SELECT
  dt.temps_id,
  3                                                            AS magasin_id,
  dc.client_id,
  dp.produit_id,
  YEAR(mr.date_from)                                          AS annee,
  mr.price_rent * GREATEST(1, DATEDIFF(mr.date_to, mr.date_from)) AS ca_locations,
  1                                                            AS nb_locations,
  GREATEST(1, DATEDIFF(mr.date_to, mr.date_from))             AS nb_jours_total
FROM database.moviemegamart_movierentals mr
INNER JOIN dim_temps dt  ON dt.date_complete = DATE(mr.date_from)
INNER JOIN dim_produit dp ON dp.type = 'film' AND dp.film_id = mr.movie_id
INNER JOIN tmp_dc_mmm dc
  ON dc.prenom_n = LOWER(SUBSTRING_INDEX(REGEXP_REPLACE(mr.cust_name, '^T', ''), ' ', 1))
  AND dc.nom_n   = LOWER(SUBSTRING_INDEX(REGEXP_REPLACE(mr.cust_name, '^T', ''), ' ', -1))
  AND dc.dob     = DATE(mr.birthdate)
WHERE mr.date_from IS NOT NULL
  AND mr.date_to IS NOT NULL
  AND mr.date_to > mr.date_from;

-- ===========================================================================
-- STEP 5 — Aggregate tables
-- ===========================================================================

-- Aggregate 1: Monthly revenue by store
INSERT INTO agg_ventes_mois_magasin
  (annee, mois, magasin_id, ca_total, marge_totale, nb_ventes, nb_clients)
SELECT
  t.annee, t.mois, f.magasin_id,
  SUM(f.ca_ventes),
  SUM(f.marge),
  SUM(f.nb_ventes),
  COUNT(DISTINCT f.client_id)
FROM fait_ventes f
JOIN dim_temps t ON t.temps_id = f.temps_id
GROUP BY t.annee, t.mois, f.magasin_id;

-- Aggregate 2: Monthly revenue by product
INSERT INTO agg_ventes_mois_produit
  (annee, mois, produit_id, type_produit, ca_total, nb_ventes)
SELECT
  t.annee, t.mois, f.produit_id, p.type,
  SUM(f.ca_ventes),
  SUM(f.nb_ventes)
FROM fait_ventes f
JOIN dim_temps   t ON t.temps_id   = f.temps_id
JOIN dim_produit p ON p.produit_id = f.produit_id
GROUP BY t.annee, t.mois, f.produit_id, p.type;

-- Aggregate 3: Monthly rentals by product and store
INSERT INTO agg_locations_mois_produit_magasin
  (annee, mois, produit_id, magasin_id, ca_total, nb_locations, nb_jours_total)
SELECT
  t.annee, t.mois, l.produit_id, l.magasin_id,
  SUM(l.ca_locations),
  SUM(l.nb_locations),
  SUM(l.nb_jours_total)
FROM fait_locations l
JOIN dim_temps t ON t.temps_id = l.temps_id
GROUP BY t.annee, t.mois, l.produit_id, l.magasin_id;

-- ===========================================================================
-- VERIFICATION
-- ===========================================================================
SELECT 'dim_produit'   AS tbl, COUNT(*) AS nb FROM dim_produit
UNION ALL SELECT 'dim_client',    COUNT(*) FROM dim_client
UNION ALL SELECT 'fait_ventes',   COUNT(*) FROM fait_ventes
UNION ALL SELECT 'fait_locations',COUNT(*) FROM fait_locations
UNION ALL SELECT 'agg_ventes_mois_magasin', COUNT(*) FROM agg_ventes_mois_magasin
UNION ALL SELECT 'agg_ventes_mois_produit', COUNT(*) FROM agg_ventes_mois_produit
UNION ALL SELECT 'agg_locations_mois_produit_magasin', COUNT(*) FROM agg_locations_mois_produit_magasin;
