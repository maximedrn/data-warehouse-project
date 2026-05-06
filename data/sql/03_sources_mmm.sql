CREATE DATABASE IF NOT EXISTS db_mmm
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE db_mmm;

DROP TABLE IF EXISTS mmm_location_film;
DROP TABLE IF EXISTS mmm_vente_film;
DROP TABLE IF EXISTS mmm_vente_gadget;
DROP TABLE IF EXISTS mmm_client;

-- ---------------------------------------------------------------------------
-- Clients (rebuilt from denormalized transaction tables)
-- Deduplication on (full_name, birth_date).
-- ---------------------------------------------------------------------------
CREATE TABLE mmm_client (
  client_id      INT          NOT NULL AUTO_INCREMENT,
  prenom         VARCHAR(100),
  initiale       CHAR(5),
  nom            VARCHAR(100),
  nom_complet    VARCHAR(300),          -- cleaned cust_name
  genre          CHAR(1),              -- sex_male: 0→F, 1→M
  date_naissance DATE,
  adresse        VARCHAR(300),
  PRIMARY KEY (client_id),
  INDEX idx_dedup (nom_complet(100), date_naissance)
);

-- ---------------------------------------------------------------------------
-- Movie Rentals
-- film_ref_id = source movie_id, resolved to integrated movie at step 11
-- ---------------------------------------------------------------------------
CREATE TABLE mmm_location_film (
  location_id  INT          NOT NULL AUTO_INCREMENT,
  source_id    INT          NOT NULL,
  film_ref_id  INT,
  date_debut   DATE,
  date_fin     DATE,
  prix_jour    DECIMAL(10,2),
  client_id    INT,
  PRIMARY KEY (location_id),
  INDEX idx_client (client_id),
  FOREIGN KEY (client_id) REFERENCES mmm_client(client_id)
);

-- ---------------------------------------------------------------------------
-- Movie Sales
-- prix_vente NULL kept for 10.6% of rows
-- ---------------------------------------------------------------------------
CREATE TABLE mmm_vente_film (
  vente_id    INT          NOT NULL AUTO_INCREMENT,
  source_id   INT          NOT NULL,
  film_ref_id INT,
  date_vente  DATE,
  prix_vente  DECIMAL(10,2),
  client_id   INT,
  PRIMARY KEY (vente_id),
  INDEX idx_client (client_id),
  FOREIGN KEY (client_id) REFERENCES mmm_client(client_id)
);

-- ---------------------------------------------------------------------------
-- Gadget Sales
-- ---------------------------------------------------------------------------
CREATE TABLE mmm_vente_gadget (
  vente_id        INT          NOT NULL AUTO_INCREMENT,
  source_id       INT          NOT NULL,
  type_gadget     VARCHAR(50),
  titre_gadget    VARCHAR(200),
  date_vente      DATE,
  prix_vente      DECIMAL(10,2),
  prix_inventaire DECIMAL(10,2),
  date_inventaire DATE,
  client_id       INT,
  PRIMARY KEY (vente_id),
  INDEX idx_client (client_id),
  FOREIGN KEY (client_id) REFERENCES mmm_client(client_id)
);
