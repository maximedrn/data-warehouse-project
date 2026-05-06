CREATE DATABASE IF NOT EXISTS db_rolap
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE db_rolap;

-- ---------------------------------------------------------------------------
-- Deletion in reverse FK dependency order
-- ---------------------------------------------------------------------------
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
-- ---------------------------------------------------------------------------
CREATE TABLE dim_temps (
  temps_id      INT          NOT NULL AUTO_INCREMENT,
  date_complete DATE         NOT NULL,
  jour          INT          NOT NULL,   -- 1-31
  mois          INT          NOT NULL,   -- 1-12
  nom_mois      VARCHAR(20),             -- 'January', ...
  trimestre     INT          NOT NULL,   -- 1-4
  annee         INT          NOT NULL,
  PRIMARY KEY (temps_id),
  UNIQUE KEY uq_date          (date_complete),
  INDEX idx_annee             (annee),
  INDEX idx_annee_mois        (annee, mois),
  INDEX idx_annee_mois_jour   (annee, mois, jour)
);

-- Initialize the time dimension (2005-2012)
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
      ELT(MONTH(d), 'January','February','March','April','May','June',
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
-- Hierarchy: Store → All Stores (1 level)
-- ---------------------------------------------------------------------------
CREATE TABLE dim_magasin (
  magasin_id INT          NOT NULL AUTO_INCREMENT,
  nom        VARCHAR(100) NOT NULL,
  adresse    VARCHAR(300),
  PRIMARY KEY (magasin_id)
);

INSERT INTO dim_magasin (magasin_id, nom) VALUES
  (1, 'BuckBoaster'),
  (2, 'MetroStarlet'),
  (3, 'MovieMegaMart');

-- ---------------------------------------------------------------------------
-- Client Dimension
-- Hierarchies: Client → Age Group → All Clients
--              Client → Gender → All Clients
-- ---------------------------------------------------------------------------
CREATE TABLE dim_client (
  client_id      INT          NOT NULL AUTO_INCREMENT,
  prenom         VARCHAR(100),
  nom            VARCHAR(100),
  date_naissance DATE,
  age            INT,                   -- computed during load ETL
  tranche_age    VARCHAR(20),           -- '<25', '25-40', '40-60', '>60'
  genre          CHAR(1),
  magasin_id     INT,
  PRIMARY KEY (client_id),
  INDEX idx_genre       (genre),
  INDEX idx_tranche_age (tranche_age),
  INDEX idx_magasin     (magasin_id),
  FOREIGN KEY (magasin_id) REFERENCES dim_magasin(magasin_id)
);

-- ---------------------------------------------------------------------------
-- Product Dimension
-- Hierarchy: Product → Type (movie/gadget) → All Products
-- ---------------------------------------------------------------------------
CREATE TABLE dim_produit (
  produit_id INT          NOT NULL AUTO_INCREMENT,
  titre      VARCHAR(300),
  type       VARCHAR(20)  NOT NULL,   -- 'film', 'gadget'
  sous_type  VARCHAR(50),
  film_id    INT,
  PRIMARY KEY (produit_id),
  INDEX idx_type     (type),
  INDEX idx_sous_type(sous_type)
);

-- ===========================================================================
-- FACT TABLES
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- Sales Fact
-- Measures: ca_ventes, prix_inventaire_total, marge, nb_ventes, est_neuf
-- Partitioned by year (redundant column with dim_temps).
-- ---------------------------------------------------------------------------
CREATE TABLE fait_ventes (
  vente_id              INT            NOT NULL AUTO_INCREMENT,
  temps_id              INT            NOT NULL,
  magasin_id            INT            NOT NULL,
  client_id             INT            NOT NULL,
  produit_id            INT            NOT NULL,
  annee                 INT            NOT NULL,   -- redundant for partitioning
  ca_ventes             DECIMAL(12,2),
  prix_inventaire_total DECIMAL(12,2),
  marge                 DECIMAL(12,2)  GENERATED ALWAYS AS (ca_ventes - prix_inventaire_total) STORED,
  nb_ventes             INT            NOT NULL DEFAULT 1,
  est_neuf              TINYINT        DEFAULT 0,
  PRIMARY KEY (vente_id, annee),
  INDEX idx_temps    (temps_id),
  INDEX idx_magasin  (magasin_id),
  INDEX idx_client   (client_id),
  INDEX idx_produit  (produit_id),
  FOREIGN KEY (temps_id)   REFERENCES dim_temps(temps_id),
  FOREIGN KEY (magasin_id) REFERENCES dim_magasin(magasin_id),
  FOREIGN KEY (client_id)  REFERENCES dim_client(client_id),
  FOREIGN KEY (produit_id) REFERENCES dim_produit(produit_id)
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
-- Measures: ca_locations, nb_locations, nb_jours_total
-- ---------------------------------------------------------------------------
CREATE TABLE fait_locations (
  location_id    INT            NOT NULL AUTO_INCREMENT,
  temps_id       INT            NOT NULL,
  magasin_id     INT            NOT NULL,
  client_id      INT            NOT NULL,
  produit_id     INT            NOT NULL,
  annee          INT            NOT NULL,   -- redundant for partitioning
  ca_locations   DECIMAL(12,2),
  nb_locations   INT            NOT NULL DEFAULT 1,
  nb_jours_total INT,
  PRIMARY KEY (location_id, annee),
  INDEX idx_temps    (temps_id),
  INDEX idx_magasin  (magasin_id),
  INDEX idx_client   (client_id),
  INDEX idx_produit  (produit_id),
  FOREIGN KEY (temps_id)   REFERENCES dim_temps(temps_id),
  FOREIGN KEY (magasin_id) REFERENCES dim_magasin(magasin_id),
  FOREIGN KEY (client_id)  REFERENCES dim_client(client_id),
  FOREIGN KEY (produit_id) REFERENCES dim_produit(produit_id)
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
-- Populated by the load ETL (step 13).
-- Referenced in the Mondrian schema for query rewriting.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- Aggregate 1: Monthly revenue by store
-- Answers 'by store, by month/year' analyses (PBI questions 2 and 4)
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
-- Answers 'top 5 movies by monthly/yearly revenue' (PBI question 1)
-- ---------------------------------------------------------------------------
CREATE TABLE agg_ventes_mois_produit (
  annee        INT            NOT NULL,
  mois         INT            NOT NULL,
  produit_id   INT            NOT NULL,
  type_produit VARCHAR(20),
  ca_total     DECIMAL(14,2),
  nb_ventes    INT,
  PRIMARY KEY (annee, mois, produit_id),
  FOREIGN KEY (produit_id) REFERENCES dim_produit(produit_id)
);

-- ---------------------------------------------------------------------------
-- Aggregate 3: Monthly rentals by product and store
-- Answers 'most rented movies by store per month' (PBI questions 4 and 5)
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
