CREATE DATABASE IF NOT EXISTS db_bb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE db_bb;

-- ---------------------------------------------------------------------------
-- Movies
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS bb_joue_dans;

DROP TABLE IF EXISTS bb_vente_film;

DROP TABLE IF EXISTS bb_vente_gadget;

DROP TABLE IF EXISTS bb_client;

DROP TABLE IF EXISTS bb_film;

DROP TABLE IF EXISTS bb_acteur;

CREATE TABLE bb_film (
  film_id INT NOT NULL AUTO_INCREMENT,
  source_id VARCHAR(20) NOT NULL, -- movie_id without T prefix
  titre VARCHAR(300),
  annee INT,
  PRIMARY KEY (film_id),
  UNIQUE KEY uq_source (source_id)
);

-- ---------------------------------------------------------------------------
-- Actors
-- ---------------------------------------------------------------------------
CREATE TABLE bb_acteur (
  acteur_id INT NOT NULL AUTO_INCREMENT,
  source_id VARCHAR(20) NOT NULL, -- actor_id without T prefix
  nom VARCHAR(200),
  PRIMARY KEY (acteur_id),
  UNIQUE KEY uq_source (source_id)
);

-- ---------------------------------------------------------------------------
-- Movie-Actor Association
-- ---------------------------------------------------------------------------
CREATE TABLE bb_joue_dans (
  film_id INT NOT NULL,
  acteur_id INT NOT NULL,
  PRIMARY KEY (film_id, acteur_id),
  FOREIGN KEY (film_id) REFERENCES bb_film (film_id),
  FOREIGN KEY (acteur_id) REFERENCES bb_acteur (acteur_id)
);

-- ---------------------------------------------------------------------------
-- Clients
-- Deduplication on (first_name, last_name, birth_date): the source key is
-- not reliable (20% duplicates in customer).
-- ---------------------------------------------------------------------------
CREATE TABLE bb_client (
  client_id INT NOT NULL AUTO_INCREMENT,
  source_code VARCHAR(20), -- original code (without T)
  prenom VARCHAR(100),
  nom VARCHAR(100),
  date_naissance DATE,
  genre CHAR(1), -- M / F (TFemale→F, TMale→M)
  PRIMARY KEY (client_id),
  INDEX idx_dedup (prenom (50), nom (50), date_naissance)
);

-- ---------------------------------------------------------------------------
-- Movie Sales
-- Source: sale_item WHERE sale_price IS NOT NULL
-- ---------------------------------------------------------------------------
CREATE TABLE bb_vente_film (
  vente_id INT NOT NULL AUTO_INCREMENT,
  source_id INT NOT NULL, -- id in sale_item
  date_vente DATE,
  prix_vente DECIMAL(10, 2),
  prix_inventaire DECIMAL(10, 2),
  type_produit VARCHAR(50), -- type without T prefix
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
-- ---------------------------------------------------------------------------
CREATE TABLE bb_vente_gadget (
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
