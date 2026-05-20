-- =============================================================================
-- Script  : 03_sources_moviemegamart.sql
-- Database: db_mmm  (MovieMegaMart reconceptualized schema)
-- Purpose : Define the reconceptualized schema for the MovieMegaMart source.
--           This schema normalizes the raw Access data loaded by mdb-loader
--           into database.moviemegamart_*.
-- Run order: 3 of 5 (before integration and ROLAP scripts)
--
-- Source tables consumed (in database.*):
--   moviemegamart_movierentals, moviemegamart_moviesales,
--   moviemegamart_gadgetsales
--
-- Data quality notes:
--   - MovieMegaMart has NO dedicated customer table in the raw Access database.
--     Customer data is denormalized across the three transaction tables.
--     mmm_client is reconstructed by UNION + name parsing + dedup.
--   - cust_name format: "FIRSTNAME [I.] LASTNAME" — split by the ETL.
--   - sex_male column: 0 → 'F', 1 → 'M'.
--   - ~10.6% of moviesales rows have prix_vente = NULL (kept as-is).
--   - film_ref_id references the raw Access movie_id; resolved to the
--     integrated film_id at integration step (job_integration).
-- =============================================================================
CREATE DATABASE IF NOT EXISTS db_mmm CHARACTER
SET
  utf8mb4 COLLATE utf8mb4_unicode_ci;

USE db_mmm;

-- Drop in reverse FK dependency order
DROP TABLE IF EXISTS mmm_location_film;

DROP TABLE IF EXISTS mmm_vente_film;

DROP TABLE IF EXISTS mmm_vente_gadget;

DROP TABLE IF EXISTS mmm_client;

-- ---------------------------------------------------------------------------
-- Clients (reconstructed from denormalized transaction tables)
-- Natural key: (nom_complet, date_naissance)
-- nom_complet preserved verbatim alongside parsed prenom/nom for traceability.
-- ---------------------------------------------------------------------------
CREATE TABLE
  mmm_client (
    client_id INT NOT NULL AUTO_INCREMENT,
    prenom VARCHAR(100),
    initiale CHAR(5), -- middle initial if present
    nom VARCHAR(100),
    nom_complet VARCHAR(300), -- cleaned full cust_name
    genre CHAR(1), -- sex_male: 0→'F', 1→'M'
    date_naissance DATE,
    adresse VARCHAR(300), -- only available in movierentals
    PRIMARY KEY (client_id),
    INDEX idx_dedup (nom_complet (100), date_naissance)
  );

-- ---------------------------------------------------------------------------
-- Movie Rentals
-- film_ref_id = raw Access movie_id; resolved to integrated film_id at step 11.
-- Revenue = prix_jour * DATEDIFF(date_fin, date_debut).
-- ---------------------------------------------------------------------------
CREATE TABLE
  mmm_location_film (
    location_id INT NOT NULL AUTO_INCREMENT,
    source_id INT NOT NULL,
    film_ref_id INT, -- raw Access movie_id (resolved later)
    date_debut DATE,
    date_fin DATE,
    prix_jour DECIMAL(10, 2),
    client_id INT,
    PRIMARY KEY (location_id),
    INDEX idx_client (client_id),
    FOREIGN KEY (client_id) REFERENCES mmm_client (client_id)
  );

-- ---------------------------------------------------------------------------
-- Movie Sales
-- ~10.6% of rows have prix_vente = NULL — kept to preserve transaction count.
-- ---------------------------------------------------------------------------
CREATE TABLE
  mmm_vente_film (
    vente_id INT NOT NULL AUTO_INCREMENT,
    source_id INT NOT NULL,
    film_ref_id INT, -- raw Access movie_id (resolved later)
    date_vente DATE,
    prix_vente DECIMAL(10, 2), -- NULL for ~10.6% of rows
    client_id INT,
    PRIMARY KEY (vente_id),
    INDEX idx_client (client_id),
    FOREIGN KEY (client_id) REFERENCES mmm_client (client_id)
  );

-- ---------------------------------------------------------------------------
-- Gadget Sales
-- Uniquely provides both prix_inventaire and date_inventaire at transaction level.
-- ---------------------------------------------------------------------------
CREATE TABLE
  mmm_vente_gadget (
    vente_id INT NOT NULL AUTO_INCREMENT,
    source_id INT NOT NULL,
    type_gadget VARCHAR(50),
    titre_gadget VARCHAR(200),
    date_vente DATE,
    prix_vente DECIMAL(10, 2),
    prix_inventaire DECIMAL(10, 2),
    date_inventaire DATE,
    client_id INT,
    PRIMARY KEY (vente_id),
    INDEX idx_client (client_id),
    FOREIGN KEY (client_id) REFERENCES mmm_client (client_id)
  );