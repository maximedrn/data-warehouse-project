-- =============================================================================
-- Script  : 05_rolap_warehouse.sql
-- Database: db_rolap  (ROLAP star schema)
-- Purpose : Create the ROLAP warehouse schema — dimensions, fact tables, and
--           aggregate tables.  Also initializes the time dimension.
-- Run order: 5 of 5  (after source and integration scripts)
--           Executed automatically by MySQL on first boot via docker-entrypoint-initdb.d.
--           On subsequent boots the script is skipped (initdb.d only fires on first boot).
--
-- Star schema layout:
--   Dimensions : dim_temps (2005-2012), dim_magasin, dim_client, dim_produit
--   Facts      : fait_ventes, fait_locations  (both partitioned by year)
--   Aggregates : agg_ventes_mois_magasin, agg_ventes_mois_produit,
--                agg_locations_mois_produit_magasin
--
-- Partitioning:
--   fait_ventes and fait_locations are RANGE-partitioned on the annee column.
--   MySQL InnoDB does not support FK constraints on partitioned tables.
--
-- Aggregate tables:
--   Pre-computed summaries used by Mondrian for MDX query rewriting.
--   They replace materialized views (not available in MySQL).
--   Declared in data/olap/moremovies.xml via <AggName> elements.
-- =============================================================================

CREATE DATABASE IF NOT EXISTS db_rolap
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE db_rolap;

-- Drop in reverse FK dependency order
DROP TABLE IF EXISTS agg_locations_mois_produit_magasin;
DROP TABLE IF EXISTS agg_ventes_mois_produit;
DROP TABLE IF EXISTS agg_ventes_mois_magasin;
DROP TABLE IF EXISTS fait_locations;
DROP TABLE IF EXISTS fait_ventes;
DROP TABLE IF EXISTS dim_produit;
DROP TABLE IF EXISTS dim_client;
DROP TABLE IF EXISTS dim_magasin;
DROP TABLE IF EXISTS dim_temps;

-- ===========================================================================
-- DIMENSIONS
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- Time Dimension
-- Hierarchy: Day → Month → Quarter → Year
-- Pre-populated for 2005-2012 (full data window) by the stored procedure below.
-- Indexed on common query patterns: year, (year, month), (year, month, day).
-- ---------------------------------------------------------------------------
CREATE TABLE dim_temps (
  temps_id      INT            NOT NULL AUTO_INCREMENT,
  date_complete DATE           NOT NULL,
  jour          INT            NOT NULL,       -- 1-31
  mois          INT            NOT NULL,       -- 1-12
  nom_mois      VARCHAR(20),                   -- 'January', 'February', ...
  trimestre     INT            NOT NULL,       -- 1-4
  annee         INT            NOT NULL,
  PRIMARY KEY (temps_id),
  UNIQUE KEY uq_date         (date_complete),
  INDEX idx_annee            (annee),
  INDEX idx_annee_mois       (annee, mois),
  INDEX idx_annee_mois_jour  (annee, mois, jour)
);

-- Populate dim_temps for every day in 2005-2012 using a stored procedure.
-- The procedure is dropped immediately after use to keep the schema clean.
DELIMITER $$
CREATE PROCEDURE IF NOT EXISTS fill_dim_temps()
BEGIN
  DECLARE d DATE DEFAULT '2005-01-01';
  WHILE d <= '2012-12-31' DO
    INSERT IGNORE INTO dim_temps (date_complete, jour, mois, nom_mois, trimestre, annee)
    VALUES (
      d,
      DAY(d),
      MONTH(d),
      ELT(MONTH(d),
        'January','February','March','April','May','June',
        'July','August','September','October','November','December'),
      QUARTER(d),
      YEAR(d)
    );
    SET d = DATE_ADD(d, INTERVAL 1 DAY);
  END WHILE;
END$$
DELIMITER ;

CALL fill_dim_temps();
DROP PROCEDURE IF EXISTS fill_dim_temps;

-- ---------------------------------------------------------------------------
-- Store Dimension
-- Static — the three stores are seeded once with fixed IDs to match db_integre.
-- Hierarchy: Store → All Stores
-- ---------------------------------------------------------------------------
CREATE TABLE dim_magasin (
  magasin_id INT            NOT NULL AUTO_INCREMENT,
  nom        VARCHAR(100)   NOT NULL,
  adresse    VARCHAR(300),
  PRIMARY KEY (magasin_id)
);

-- Fixed IDs must match db_integre.magasin (1=BB, 2=MS, 3=MMM)
INSERT INTO dim_magasin (magasin_id, nom) VALUES
  (1, 'BuckBoaster'),
  (2, 'MetroStarlet'),
  (3, 'MovieMegaMart');

-- ---------------------------------------------------------------------------
-- Client Dimension
-- Hierarchies: Client → Age Group → All Clients
--              Client → Gender    → All Clients
-- age and tranche_age are computed during ETL using reference date 2010-01-01.
-- tranche_age buckets: '<25' | '25-40' | '40-60' | '>60' | 'Unknown'
-- ---------------------------------------------------------------------------
CREATE TABLE dim_client (
  client_id      INT            NOT NULL AUTO_INCREMENT,
  prenom         VARCHAR(100),
  nom            VARCHAR(100),
  date_naissance DATE,
  age            INT,                          -- TIMESTAMPDIFF(YEAR, dob, '2010-01-01')
  tranche_age    VARCHAR(20),                  -- age bucket for MDX hierarchy
  genre          CHAR(1),                      -- 'M' or 'F'
  magasin_id     INT,
  PRIMARY KEY (client_id),
  INDEX idx_genre       (genre),
  INDEX idx_tranche_age (tranche_age),
  INDEX idx_magasin     (magasin_id),
  FOREIGN KEY (magasin_id) REFERENCES dim_magasin(magasin_id)
);

-- ---------------------------------------------------------------------------
-- Product Dimension
-- Hierarchy: Product → Subtype → Type (film/gadget) → All Products
-- film_id links to the integrated catalogue (NULL for gadgets).
-- ---------------------------------------------------------------------------
CREATE TABLE dim_produit (
  produit_id INT            NOT NULL AUTO_INCREMENT,
  titre      VARCHAR(300),
  type       VARCHAR(20)    NOT NULL,          -- 'film' or 'gadget'
  sous_type  VARCHAR(50),                      -- e.g. DVD, VHS, Blu-ray, gadget category
  film_id    INT,                              -- NULL for gadgets
  PRIMARY KEY (produit_id),
  INDEX idx_type     (type),
  INDEX idx_sous_type(sous_type)
);

-- ===========================================================================
-- FACT TABLES
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- Sales Fact
-- Grain: one row per sale transaction.
-- Measures: ca_ventes, prix_inventaire_total, marge (generated), nb_ventes, est_neuf
-- marge is a GENERATED ALWAYS column (ca_ventes - prix_inventaire_total).
-- annee is redundant with dim_temps but required for the RANGE partition key.
-- InnoDB FK constraints are not supported on partitioned tables.
-- ---------------------------------------------------------------------------
CREATE TABLE fait_ventes (
  vente_id              INT            NOT NULL AUTO_INCREMENT,
  temps_id              INT            NOT NULL,
  magasin_id            INT            NOT NULL,
  client_id             INT            NOT NULL,
  produit_id            INT            NOT NULL,
  annee                 INT            NOT NULL,   -- partition key (redundant with dim_temps)
  ca_ventes             DECIMAL(12,2),
  prix_inventaire_total DECIMAL(12,2),
  marge                 DECIMAL(12,2)  GENERATED ALWAYS AS (ca_ventes - prix_inventaire_total) STORED,
  nb_ventes             INT            NOT NULL DEFAULT 1,
  est_neuf              TINYINT        DEFAULT 0,
  PRIMARY KEY (vente_id, annee),
  INDEX idx_temps   (temps_id),
  INDEX idx_magasin (magasin_id),
  INDEX idx_client  (client_id),
  INDEX idx_produit (produit_id)
  -- No FK on partitioned tables (InnoDB limitation)
)
PARTITION BY RANGE (annee) (
  PARTITION p2005 VALUES LESS THAN (2006),
  PARTITION p2006 VALUES LESS THAN (2007),
  PARTITION p2007 VALUES LESS THAN (2008),
  PARTITION p2008 VALUES LESS THAN (2009),
  PARTITION p2009 VALUES LESS THAN (2010),
  PARTITION p2010 VALUES LESS THAN (2011),
  PARTITION p2011 VALUES LESS THAN (2012),
  PARTITION pmax  VALUES LESS THAN MAXVALUE
);

-- ---------------------------------------------------------------------------
-- Rentals Fact
-- Grain: one row per rental transaction.
-- Measures: ca_locations, nb_locations, nb_jours_total
-- ca_locations = prix_jour * nb_jours_total (computed during ETL).
-- annee is redundant with dim_temps but required for the RANGE partition key.
-- ---------------------------------------------------------------------------
CREATE TABLE fait_locations (
  location_id    INT            NOT NULL AUTO_INCREMENT,
  temps_id       INT            NOT NULL,
  magasin_id     INT            NOT NULL,
  client_id      INT            NOT NULL,
  produit_id     INT            NOT NULL,
  annee          INT            NOT NULL,          -- partition key (redundant with dim_temps)
  ca_locations   DECIMAL(12,2),
  nb_locations   INT            NOT NULL DEFAULT 1,
  nb_jours_total INT,
  PRIMARY KEY (location_id, annee),
  INDEX idx_temps   (temps_id),
  INDEX idx_magasin (magasin_id),
  INDEX idx_client  (client_id),
  INDEX idx_produit (produit_id)
  -- No FK on partitioned tables (InnoDB limitation)
)
PARTITION BY RANGE (annee) (
  PARTITION p2005 VALUES LESS THAN (2006),
  PARTITION p2006 VALUES LESS THAN (2007),
  PARTITION p2007 VALUES LESS THAN (2008),
  PARTITION p2008 VALUES LESS THAN (2009),
  PARTITION p2009 VALUES LESS THAN (2010),
  PARTITION p2010 VALUES LESS THAN (2011),
  PARTITION p2011 VALUES LESS THAN (2012),
  PARTITION pmax  VALUES LESS THAN MAXVALUE
);

-- ===========================================================================
-- AGGREGATE TABLES
-- Replace materialized views (not available in MySQL).
-- Populated by the load ETL (06_load_rolap_from_raw.sql or transform_load_aggregates.ktr).
-- Referenced in data/olap/moremovies.xml via <AggName> for Mondrian query rewriting.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- Aggregate 1: Monthly revenue by store
-- Grain: (annee, mois, magasin_id)
-- Answers Q2 (monthly revenue by store) and Q4 (most rented movies by store).
-- Mondrian rewrites Sales cube queries filtered by Store + Time[Month/Year].
-- ---------------------------------------------------------------------------
CREATE TABLE agg_ventes_mois_magasin (
  annee        INT            NOT NULL,
  mois         INT            NOT NULL,
  magasin_id   INT            NOT NULL,
  ca_total     DECIMAL(14,2),
  marge_totale DECIMAL(14,2),
  nb_ventes    INT,
  nb_clients   INT,
  PRIMARY KEY (annee, mois, magasin_id),
  FOREIGN KEY (magasin_id) REFERENCES dim_magasin(magasin_id)
);

-- ---------------------------------------------------------------------------
-- Aggregate 2: Monthly revenue by product
-- Grain: (annee, mois, produit_id)
-- Answers Q1 (top movies by monthly/yearly revenue).
-- Mondrian rewrites Sales cube queries filtered by Product + Time[Month/Year].
-- ---------------------------------------------------------------------------
CREATE TABLE agg_ventes_mois_produit (
  annee        INT            NOT NULL,
  mois         INT            NOT NULL,
  produit_id   INT            NOT NULL,
  type_produit VARCHAR(20),                    -- denormalized from dim_produit for faster MDX
  ca_total     DECIMAL(14,2),
  nb_ventes    INT,
  PRIMARY KEY (annee, mois, produit_id),
  FOREIGN KEY (produit_id) REFERENCES dim_produit(produit_id)
);

-- ---------------------------------------------------------------------------
-- Aggregate 3: Monthly rentals by product and store
-- Grain: (annee, mois, produit_id, magasin_id)
-- Answers Q4 (most rented movies by store) and Q5 (monthly rental trends).
-- Mondrian rewrites Rentals cube queries filtered by Product + Store + Time.
-- ---------------------------------------------------------------------------
CREATE TABLE agg_locations_mois_produit_magasin (
  annee          INT            NOT NULL,
  mois           INT            NOT NULL,
  produit_id     INT            NOT NULL,
  magasin_id     INT            NOT NULL,
  ca_total       DECIMAL(14,2),
  nb_locations   INT,
  nb_jours_total INT,
  PRIMARY KEY (annee, mois, produit_id, magasin_id),
  FOREIGN KEY (produit_id) REFERENCES dim_produit(produit_id),
  FOREIGN KEY (magasin_id) REFERENCES dim_magasin(magasin_id)
);
