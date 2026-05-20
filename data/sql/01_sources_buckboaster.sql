-- =============================================================================
-- Script  : 01_sources_buckboaster.sql
-- Database: db_bb   (BuckBoaster reconceptualized schema)
-- Purpose : Define the reconceptualized schema for the BuckBoaster source.
--           This schema normalizes the raw Access data loaded by mdb-loader
--           into database.buckboaster_*.
-- Run order: 1 of 5 (before integration and ROLAP scripts)
--
-- Source tables consumed (in database.*):
--   buckboaster_movie, buckboaster_actor, buckboaster_appears_in,
--   buckboaster_customer, buckboaster_sale_item, buckboaster_gadget
--
-- Data quality notes:
--   - All Access string columns carry a spurious 'T' prefix (e.g. "Tmovie_id").
--     The ETL transformations strip it; schemas here store already-cleaned values.
--   - sex column values: "TFemale" / "TMale" → mapped to 'F' / 'M'.
--   - dob stored as VARCHAR "MM/DD/YY(YY)" → parsed to DATE by the ETL.
--   - ~20% duplicate rows in buckboaster_customer → dedup on (prenom, nom, dob).
-- =============================================================================
CREATE DATABASE IF NOT EXISTS db_bb CHARACTER
SET
  utf8mb4 COLLATE utf8mb4_unicode_ci;

USE db_bb;

-- ---------------------------------------------------------------------------
-- Drop in reverse FK dependency order before recreating
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS bb_joue_dans;

DROP TABLE IF EXISTS bb_vente_film;

DROP TABLE IF EXISTS bb_vente_gadget;

DROP TABLE IF EXISTS bb_client;

DROP TABLE IF EXISTS bb_film;

DROP TABLE IF EXISTS bb_acteur;

-- ---------------------------------------------------------------------------
-- Movies
-- source_id = movie_id without the T prefix (VARCHAR because Access IDs vary)
-- ---------------------------------------------------------------------------
CREATE TABLE
  bb_film (
    film_id INT NOT NULL AUTO_INCREMENT,
    source_id VARCHAR(20) NOT NULL, -- original movie_id, T-prefix stripped
    titre VARCHAR(300),
    annee INT,
    PRIMARY KEY (film_id),
    UNIQUE KEY uq_source (source_id)
  );

-- ---------------------------------------------------------------------------
-- Actors
-- ---------------------------------------------------------------------------
CREATE TABLE
  bb_acteur (
    acteur_id INT NOT NULL AUTO_INCREMENT,
    source_id VARCHAR(20) NOT NULL, -- original actor_id, T-prefix stripped
    nom VARCHAR(200),
    PRIMARY KEY (acteur_id),
    UNIQUE KEY uq_source (source_id)
  );

-- ---------------------------------------------------------------------------
-- Movie–Actor associations
-- ---------------------------------------------------------------------------
CREATE TABLE
  bb_joue_dans (
    film_id INT NOT NULL,
    acteur_id INT NOT NULL,
    PRIMARY KEY (film_id, acteur_id),
    FOREIGN KEY (film_id) REFERENCES bb_film (film_id),
    FOREIGN KEY (acteur_id) REFERENCES bb_acteur (acteur_id)
  );

-- ---------------------------------------------------------------------------
-- Clients
-- Natural key: (prenom, nom, date_naissance) — source_code kept for traceability.
-- Deduplication on the natural key removes the ~20% duplicate rows.
-- ---------------------------------------------------------------------------
CREATE TABLE
  bb_client (
    client_id INT NOT NULL AUTO_INCREMENT,
    source_code VARCHAR(20), -- original code, T-prefix stripped
    prenom VARCHAR(100),
    nom VARCHAR(100),
    date_naissance DATE,
    genre CHAR(1), -- 'F' (TFemale) or 'M' (TMale)
    PRIMARY KEY (client_id),
    INDEX idx_dedup (prenom (50), nom (50), date_naissance)
  );

-- ---------------------------------------------------------------------------
-- Movie Sales
-- Source: buckboaster_sale_item WHERE sale_price IS NOT NULL
-- prix_inventaire = inventory_price at time of sale (kept for margin calculation)
-- ---------------------------------------------------------------------------
CREATE TABLE
  bb_vente_film (
    vente_id INT NOT NULL AUTO_INCREMENT,
    source_id INT NOT NULL, -- id in buckboaster_sale_item
    date_vente DATE,
    prix_vente DECIMAL(10, 2),
    prix_inventaire DECIMAL(10, 2),
    type_produit VARCHAR(50), -- product type, T-prefix stripped
    client_id INT,
    film_id INT,
    PRIMARY KEY (vente_id),
    INDEX idx_client (client_id),
    INDEX idx_film (film_id),
    FOREIGN KEY (client_id) REFERENCES bb_client (client_id),
    FOREIGN KEY (film_id) REFERENCES bb_film (film_id)
  );

-- ---------------------------------------------------------------------------
-- Gadget Sales
-- BuckBoaster also sells physical gadgets (accessories); tracked separately
-- from film sales because they carry a type and inventory price.
-- ---------------------------------------------------------------------------
CREATE TABLE
  bb_vente_gadget (
    vente_id INT NOT NULL AUTO_INCREMENT,
    source_id INT NOT NULL,
    titre VARCHAR(200),
    type_gadget VARCHAR(50),
    date_vente DATE,
    prix_vente DECIMAL(10, 2),
    prix_inventaire DECIMAL(10, 2),
    client_id INT,
    PRIMARY KEY (vente_id),
    INDEX idx_client (client_id),
    FOREIGN KEY (client_id) REFERENCES bb_client (client_id)
  );