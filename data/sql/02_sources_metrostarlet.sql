-- =============================================================================
-- Script  : 02_sources_metrostarlet.sql
-- Database: db_ms   (MetroStarlet reconceptualized schema)
-- Purpose : Define the reconceptualized schema for the MetroStarlet source.
--           This schema normalizes the raw Access data loaded by mdb-loader
--           into database.metrostarlet_*.
-- Run order: 2 of 5 (before integration and ROLAP scripts)
--
-- Source tables consumed (in database.*):
--   metrostarlet_movie, metrostarlet_actor, metrostarlet_appears_in,
--   metrostarlet_customer, metrostarlet_copy_for_rent,
--   metrostarlet_copy_for_sale, metrostarlet_copy_rented_to
--
-- Data quality notes:
--   - 100% of string/date columns carry a spurious 'T' prefix in the raw
--     Access export.  All ETL steps strip it via TRIM(LEADING 'T' FROM ...).
--   - birthday stored as VARCHAR "TYYYY-MM-DD" → cleaned then parsed to DATE.
--   - gender values ('M'/'F') are already correct — no mapping required.
--   - MetroStarlet is the richest movie source (director, writer, release price).
--     It is used as the primary source in the integration step.
-- =============================================================================
CREATE DATABASE IF NOT EXISTS db_ms CHARACTER
SET
  utf8mb4 COLLATE utf8mb4_unicode_ci;

USE db_ms;

-- Drop in reverse FK dependency order
DROP TABLE IF EXISTS ms_joue_dans;

DROP TABLE IF EXISTS ms_location;

DROP TABLE IF EXISTS ms_copie_vente;

DROP TABLE IF EXISTS ms_copie_location;

DROP TABLE IF EXISTS ms_client;

DROP TABLE IF EXISTS ms_film;

DROP TABLE IF EXISTS ms_acteur;

-- ---------------------------------------------------------------------------
-- Movies
-- Primary source for the integration step: carries the most complete metadata.
-- ---------------------------------------------------------------------------
CREATE TABLE
  ms_film (
    film_id INT NOT NULL AUTO_INCREMENT,
    source_id INT NOT NULL, -- original movieid
    titre VARCHAR(300),
    annee_production INT,
    date_sortie DATE,
    prix_sortie DECIMAL(10, 2),
    realisateur VARCHAR(200),
    scenariste VARCHAR(200),
    PRIMARY KEY (film_id),
    UNIQUE KEY uq_source (source_id)
  );

-- ---------------------------------------------------------------------------
-- Actors
-- ---------------------------------------------------------------------------
CREATE TABLE
  ms_acteur (
    acteur_id INT NOT NULL AUTO_INCREMENT,
    source_id INT NOT NULL,
    nom VARCHAR(200),
    PRIMARY KEY (acteur_id),
    UNIQUE KEY uq_source (source_id)
  );

-- ---------------------------------------------------------------------------
-- Movie–Actor associations
-- ---------------------------------------------------------------------------
CREATE TABLE
  ms_joue_dans (
    film_id INT NOT NULL,
    acteur_id INT NOT NULL,
    PRIMARY KEY (film_id, acteur_id),
    FOREIGN KEY (film_id) REFERENCES ms_film (film_id),
    FOREIGN KEY (acteur_id) REFERENCES ms_acteur (acteur_id)
  );

-- ---------------------------------------------------------------------------
-- Clients
-- birthday has a T prefix on 100% of rows → cleaned in ETL.
-- source_code is a sequential integer key from Access; used as the upsert key.
-- ---------------------------------------------------------------------------
CREATE TABLE
  ms_client (
    client_id INT NOT NULL AUTO_INCREMENT,
    source_code INT, -- original Access code (sequential)
    prenom VARCHAR(100),
    initiale CHAR(5), -- middle initial if present
    nom VARCHAR(100),
    genre CHAR(1), -- 'M' or 'F'
    date_naissance DATE, -- parsed from T-prefixed VARCHAR
    adresse VARCHAR(300),
    PRIMARY KEY (client_id),
    INDEX idx_source (source_code)
  );

-- ---------------------------------------------------------------------------
-- Rental copies
-- Physical copies of movies available for rent.
-- disposed flag: 1 = copy retired from inventory.
-- ---------------------------------------------------------------------------
CREATE TABLE
  ms_copie_location (
    copie_id INT NOT NULL AUTO_INCREMENT,
    source_id INT NOT NULL,
    type_copie VARCHAR(50),
    disposed TINYINT DEFAULT 0,
    film_id INT,
    PRIMARY KEY (copie_id),
    UNIQUE KEY uq_source (source_id),
    FOREIGN KEY (film_id) REFERENCES ms_film (film_id)
  );

-- ---------------------------------------------------------------------------
-- Sale copies
-- Physical copies that were sold to customers.
-- est_neuf: 1 = sold as new, 0 = sold as used.
-- ---------------------------------------------------------------------------
CREATE TABLE
  ms_copie_vente (
    copie_id INT NOT NULL AUTO_INCREMENT,
    source_id INT NOT NULL,
    type_copie VARCHAR(50),
    est_neuf TINYINT DEFAULT 0, -- 1 = new copy, 0 = used copy
    prix_vente DECIMAL(10, 2),
    date_vente DATE,
    film_id INT,
    client_id INT,
    PRIMARY KEY (copie_id),
    UNIQUE KEY uq_source (source_id),
    FOREIGN KEY (film_id) REFERENCES ms_film (film_id),
    FOREIGN KEY (client_id) REFERENCES ms_client (client_id)
  );

-- ---------------------------------------------------------------------------
-- Rental transactions
-- Links a rental copy to a customer for a date range with a daily price.
-- Revenue = prix_jour * DATEDIFF(date_fin, date_debut).
-- ---------------------------------------------------------------------------
CREATE TABLE
  ms_location (
    location_id INT NOT NULL AUTO_INCREMENT,
    copie_id INT,
    client_id INT,
    date_debut DATE,
    date_fin DATE,
    prix_jour DECIMAL(10, 2),
    PRIMARY KEY (location_id),
    INDEX idx_copie (copie_id),
    INDEX idx_client (client_id),
    FOREIGN KEY (copie_id) REFERENCES ms_copie_location (copie_id),
    FOREIGN KEY (client_id) REFERENCES ms_client (client_id)
  );