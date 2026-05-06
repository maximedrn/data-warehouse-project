CREATE DATABASE IF NOT EXISTS db_ms
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE db_ms;

DROP TABLE IF EXISTS ms_joue_dans;
DROP TABLE IF EXISTS ms_location;
DROP TABLE IF EXISTS ms_copie_vente;
DROP TABLE IF EXISTS ms_copie_location;
DROP TABLE IF EXISTS ms_client;
DROP TABLE IF EXISTS ms_film;
DROP TABLE IF EXISTS ms_acteur;

-- ---------------------------------------------------------------------------
-- Movies
-- ---------------------------------------------------------------------------
CREATE TABLE ms_film (
  film_id          INT          NOT NULL AUTO_INCREMENT,
  source_id        INT          NOT NULL,   -- original movieid
  titre            VARCHAR(300),
  annee_production INT,
  date_sortie      DATE,
  prix_sortie      DECIMAL(10,2),
  realisateur      VARCHAR(200),
  scenariste       VARCHAR(200),
  PRIMARY KEY (film_id),
  UNIQUE KEY uq_source (source_id)
);

-- ---------------------------------------------------------------------------
-- Actors
-- ---------------------------------------------------------------------------
CREATE TABLE ms_acteur (
  acteur_id  INT          NOT NULL AUTO_INCREMENT,
  source_id  INT          NOT NULL,
  nom        VARCHAR(200),
  PRIMARY KEY (acteur_id),
  UNIQUE KEY uq_source (source_id)
);

-- ---------------------------------------------------------------------------
-- Movie-Actor Association
-- ---------------------------------------------------------------------------
CREATE TABLE ms_joue_dans (
  film_id    INT NOT NULL,
  acteur_id  INT NOT NULL,
  PRIMARY KEY (film_id, acteur_id),
  FOREIGN KEY (film_id)   REFERENCES ms_film(film_id),
  FOREIGN KEY (acteur_id) REFERENCES ms_acteur(acteur_id)
);

-- ---------------------------------------------------------------------------
-- Clients
-- Note: birthday has a T prefix on 100% of rows → cleaned.
-- The source key (sequential code) is not stable: surrogate key used.
-- ---------------------------------------------------------------------------
CREATE TABLE ms_client (
  client_id      INT          NOT NULL AUTO_INCREMENT,
  source_code    INT,                   -- original code
  prenom         VARCHAR(100),
  initiale       CHAR(5),
  nom            VARCHAR(100),
  genre          CHAR(1),
  date_naissance DATE,                  -- T prefix removed
  adresse        VARCHAR(300),
  PRIMARY KEY (client_id),
  INDEX idx_source (source_code)
);

-- ---------------------------------------------------------------------------
-- Rental Copies
-- ---------------------------------------------------------------------------
CREATE TABLE ms_copie_location (
  copie_id   INT          NOT NULL AUTO_INCREMENT,
  source_id  INT          NOT NULL,
  type_copie VARCHAR(50),
  disposed   TINYINT      DEFAULT 0,
  film_id    INT,
  PRIMARY KEY (copie_id),
  UNIQUE KEY uq_source (source_id),
  FOREIGN KEY (film_id) REFERENCES ms_film(film_id)
);

-- ---------------------------------------------------------------------------
-- Sale Copies
-- ---------------------------------------------------------------------------
CREATE TABLE ms_copie_vente (
  copie_id    INT          NOT NULL AUTO_INCREMENT,
  source_id   INT          NOT NULL,
  type_copie  VARCHAR(50),
  est_neuf    TINYINT      DEFAULT 0,
  prix_vente  DECIMAL(10,2),
  date_vente  DATE,
  film_id     INT,
  client_id   INT,
  PRIMARY KEY (copie_id),
  UNIQUE KEY uq_source (source_id),
  FOREIGN KEY (film_id)   REFERENCES ms_film(film_id),
  FOREIGN KEY (client_id) REFERENCES ms_client(client_id)
);

-- ---------------------------------------------------------------------------
-- Rentals (transactions)
-- ---------------------------------------------------------------------------
CREATE TABLE ms_location (
  location_id INT          NOT NULL AUTO_INCREMENT,
  copie_id    INT,
  client_id   INT,
  date_debut  DATE,
  date_fin    DATE,
  prix_jour   DECIMAL(10,2),
  PRIMARY KEY (location_id),
  INDEX idx_copie  (copie_id),
  INDEX idx_client (client_id),
  FOREIGN KEY (copie_id)  REFERENCES ms_copie_location(copie_id),
  FOREIGN KEY (client_id) REFERENCES ms_client(client_id)
);
