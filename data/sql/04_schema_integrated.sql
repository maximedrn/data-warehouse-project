-- =============================================================================
-- Script  : 04_schema_integrated.sql
-- Database: db_integre  (unified integrated schema)
-- Purpose : Define the integrated schema that merges the three sources
--           (BuckBoaster, MetroStarlet, MovieMegaMart) into a single consistent
--           data model used as the staging area for the ROLAP warehouse.
-- Run order: 4 of 5 (after the three source scripts, before 05_rolap_warehouse)
--
-- Integration rules:
--   Movies  : BB + MS merged on normalized title (lowercase, alphanumeric).
--             MS records take priority (richer metadata).
--             MMM references films by raw Access movie_id (resolved at ETL time).
--   Actors  : BB + MS merged on normalized name; MMM has no actor data.
--   Clients : NOT merged across sources — each source population is kept separate.
--             magasin_id identifies the origin store; source column ('BB','MS','MMM')
--             keeps traceability.
--   Products: One row per (titre, type, magasin_id) to allow store-specific pricing.
--   Sales   : Union of all three sources' film + gadget sales.
--   Rentals : MS + MMM only (BuckBoaster has no rental activity).
-- =============================================================================
CREATE DATABASE IF NOT EXISTS db_integre CHARACTER
SET
  utf8mb4 COLLATE utf8mb4_unicode_ci;

USE db_integre;

-- Drop in reverse FK dependency order
DROP TABLE IF EXISTS joue_dans;

DROP TABLE IF EXISTS location;

DROP TABLE IF EXISTS vente;

DROP TABLE IF EXISTS produit;

DROP TABLE IF EXISTS client;

DROP TABLE IF EXISTS acteur;

DROP TABLE IF EXISTS film;

DROP TABLE IF EXISTS magasin;

-- ---------------------------------------------------------------------------
-- Stores
-- Static reference table — the 3 stores seeded as constants.
-- magasin_id is intentionally fixed (1/2/3) so all FK references are stable.
-- ---------------------------------------------------------------------------
CREATE TABLE
  magasin (
    magasin_id INT NOT NULL AUTO_INCREMENT,
    nom VARCHAR(100) NOT NULL,
    adresse VARCHAR(300),
    PRIMARY KEY (magasin_id)
  );

-- Fixed IDs: 1=BuckBoaster, 2=MetroStarlet, 3=MovieMegaMart
INSERT INTO
  magasin (magasin_id, nom)
VALUES
  (1, 'BuckBoaster'),
  (2, 'MetroStarlet'),
  (3, 'MovieMegaMart');

-- ---------------------------------------------------------------------------
-- Movies
-- BB + MS merge: MS inserted first; BB rows added only when their normalized
-- title does not already exist.
-- type_film kept for future classification (not populated by all sources).
-- ---------------------------------------------------------------------------
CREATE TABLE
  film (
    film_id INT NOT NULL AUTO_INCREMENT,
    titre VARCHAR(300),
    annee_production INT,
    date_sortie DATE, -- MS only
    prix_sortie DECIMAL(10, 2), -- MS only
    realisateur VARCHAR(200), -- MS only
    scenariste VARCHAR(200), -- MS only
    type_film VARCHAR(50),
    PRIMARY KEY (film_id),
    INDEX idx_titre (titre (100))
  );

-- ---------------------------------------------------------------------------
-- Actors
-- BB + MS merge on normalized name; MMM has no actor data.
-- ---------------------------------------------------------------------------
CREATE TABLE
  acteur (
    acteur_id INT NOT NULL AUTO_INCREMENT,
    nom VARCHAR(200),
    PRIMARY KEY (acteur_id),
    INDEX idx_nom (nom (100))
  );

-- ---------------------------------------------------------------------------
-- Movie–Actor associations
-- ---------------------------------------------------------------------------
CREATE TABLE
  joue_dans (
    film_id INT NOT NULL,
    acteur_id INT NOT NULL,
    PRIMARY KEY (film_id, acteur_id),
    FOREIGN KEY (film_id) REFERENCES film (film_id),
    FOREIGN KEY (acteur_id) REFERENCES acteur (acteur_id)
  );

-- ---------------------------------------------------------------------------
-- Clients
-- Not merged across sources — no reliable cross-source identifier exists.
-- magasin_id tags which store the client belongs to.
-- source_code allows traceability back to the original Access record.
-- ---------------------------------------------------------------------------
CREATE TABLE
  client (
    client_id INT NOT NULL AUTO_INCREMENT,
    prenom VARCHAR(100),
    initiale CHAR(5),
    nom VARCHAR(100),
    date_naissance DATE,
    genre CHAR(1),
    adresse VARCHAR(300),
    magasin_id INT NOT NULL,
    source CHAR(3), -- 'BB', 'MS', or 'MMM'
    source_code VARCHAR(30),
    PRIMARY KEY (client_id),
    INDEX idx_magasin (magasin_id),
    FOREIGN KEY (magasin_id) REFERENCES magasin (magasin_id)
  );

-- ---------------------------------------------------------------------------
-- Products (films and gadgets materialized per store)
-- One row per (titre, type, magasin_id) — store-specific because pricing
-- and inventory can differ between stores for the same product.
-- film_id links back to the integrated film catalogue (NULL for gadgets).
-- ---------------------------------------------------------------------------
CREATE TABLE
  produit (
    produit_id INT NOT NULL AUTO_INCREMENT,
    titre VARCHAR(300),
    type VARCHAR(20) NOT NULL, -- 'film' or 'gadget'
    sous_type VARCHAR(50), -- e.g. VHS, DVD, Blu-ray, or gadget category
    prix_inventaire DECIMAL(10, 2),
    date_inventaire DATE,
    film_id INT, -- NULL for gadgets
    magasin_id INT,
    PRIMARY KEY (produit_id),
    INDEX idx_type (type),
    INDEX idx_film (film_id),
    INDEX idx_magasin (magasin_id),
    FOREIGN KEY (film_id) REFERENCES film (film_id),
    FOREIGN KEY (magasin_id) REFERENCES magasin (magasin_id)
  );

-- ---------------------------------------------------------------------------
-- Sales
-- Union of BB + MS + MMM film and gadget sales.
-- est_neuf only meaningful for MS (is_new flag on sale copies).
-- ---------------------------------------------------------------------------
CREATE TABLE
  vente (
    vente_id INT NOT NULL AUTO_INCREMENT,
    date_vente DATE,
    prix_vente DECIMAL(10, 2),
    est_neuf TINYINT DEFAULT 0, -- 1 = sold as new (MS only)
    client_id INT,
    produit_id INT,
    magasin_id INT NOT NULL,
    source CHAR(3), -- 'BB', 'MS', or 'MMM'
    PRIMARY KEY (vente_id),
    INDEX idx_date (date_vente),
    INDEX idx_client (client_id),
    INDEX idx_produit (produit_id),
    INDEX idx_magasin (magasin_id),
    FOREIGN KEY (client_id) REFERENCES client (client_id),
    FOREIGN KEY (produit_id) REFERENCES produit (produit_id),
    FOREIGN KEY (magasin_id) REFERENCES magasin (magasin_id)
  );

-- ---------------------------------------------------------------------------
-- Rentals
-- MS + MMM only — BuckBoaster has no rental activity.
-- Revenue = prix_jour * DATEDIFF(date_fin, date_debut).
-- ---------------------------------------------------------------------------
CREATE TABLE
  location (
    location_id INT NOT NULL AUTO_INCREMENT,
    date_debut DATE,
    date_fin DATE,
    prix_jour DECIMAL(10, 2),
    client_id INT,
    produit_id INT,
    magasin_id INT NOT NULL,
    source CHAR(3), -- 'MS' or 'MMM'
    PRIMARY KEY (location_id),
    INDEX idx_date_debut (date_debut),
    INDEX idx_client (client_id),
    INDEX idx_produit (produit_id),
    INDEX idx_magasin (magasin_id),
    FOREIGN KEY (client_id) REFERENCES client (client_id),
    FOREIGN KEY (produit_id) REFERENCES produit (produit_id),
    FOREIGN KEY (magasin_id) REFERENCES magasin (magasin_id)
  );