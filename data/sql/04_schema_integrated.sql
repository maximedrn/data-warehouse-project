CREATE DATABASE IF NOT EXISTS db_integre
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE db_integre;

DROP TABLE IF EXISTS joue_dans;
DROP TABLE IF EXISTS location;
DROP TABLE IF EXISTS vente;
DROP TABLE IF EXISTS produit;
DROP TABLE IF EXISTS client;
DROP TABLE IF EXISTS acteur;
DROP TABLE IF EXISTS film;
DROP TABLE IF EXISTS magasin;

-- ---------------------------------------------------------------------------
-- Stores (enrichment: absent from all sources)
-- ---------------------------------------------------------------------------
CREATE TABLE magasin (
  magasin_id  INT          NOT NULL AUTO_INCREMENT,
  nom         VARCHAR(100) NOT NULL,
  adresse     VARCHAR(300),
  PRIMARY KEY (magasin_id)
);

-- Static data — the 3 stores
INSERT INTO magasin (magasin_id, nom) VALUES
  (1, 'BuckBoaster'),
  (2, 'MetroStarlet'),
  (3, 'MovieMegaMart');

-- ---------------------------------------------------------------------------
-- Movies
-- BB+MS merge by title normalization.
-- MS records take priority (more complete).
-- ---------------------------------------------------------------------------
CREATE TABLE film (
  film_id          INT          NOT NULL AUTO_INCREMENT,
  titre            VARCHAR(300),
  annee_production INT,
  date_sortie      DATE,
  prix_sortie      DECIMAL(10,2),
  realisateur      VARCHAR(200),
  scenariste       VARCHAR(200),
  type_film        VARCHAR(50),
  PRIMARY KEY (film_id),
  INDEX idx_titre (titre(100))
);

-- ---------------------------------------------------------------------------
-- Actors
-- ---------------------------------------------------------------------------
CREATE TABLE acteur (
  acteur_id   INT          NOT NULL AUTO_INCREMENT,
  nom         VARCHAR(200),
  PRIMARY KEY (acteur_id),
  INDEX idx_nom (nom(100))
);

-- ---------------------------------------------------------------------------
-- Movie-Actor Association
-- ---------------------------------------------------------------------------
CREATE TABLE joue_dans (
  film_id     INT NOT NULL,
  acteur_id   INT NOT NULL,
  PRIMARY KEY (film_id, acteur_id),
  FOREIGN KEY (film_id)   REFERENCES film(film_id),
  FOREIGN KEY (acteur_id) REFERENCES acteur(acteur_id)
);

-- ---------------------------------------------------------------------------
-- Clients (not merged across sources)
-- ---------------------------------------------------------------------------
CREATE TABLE client (
  client_id       INT          NOT NULL AUTO_INCREMENT,
  prenom          VARCHAR(100),
  initiale        CHAR(5),
  nom             VARCHAR(100),
  date_naissance  DATE,
  genre           CHAR(1),
  adresse         VARCHAR(300),
  magasin_id      INT          NOT NULL,
  source          CHAR(3),              -- 'BB', 'MS', 'MMM'
  source_code     VARCHAR(30),
  PRIMARY KEY (client_id),
  INDEX idx_magasin (magasin_id),
  FOREIGN KEY (magasin_id) REFERENCES magasin(magasin_id)
);

-- ---------------------------------------------------------------------------
-- Products (movie or gadget, materialized in a store)
-- ---------------------------------------------------------------------------
CREATE TABLE produit (
  produit_id      INT          NOT NULL AUTO_INCREMENT,
  titre           VARCHAR(300),
  type            VARCHAR(20)  NOT NULL,   -- 'film', 'gadget'
  sous_type       VARCHAR(50),
  prix_inventaire DECIMAL(10,2),
  date_inventaire DATE,
  film_id         INT,
  magasin_id      INT,
  PRIMARY KEY (produit_id),
  INDEX idx_type     (type),
  INDEX idx_film     (film_id),
  INDEX idx_magasin  (magasin_id),
  FOREIGN KEY (film_id)    REFERENCES film(film_id),
  FOREIGN KEY (magasin_id) REFERENCES magasin(magasin_id)
);

-- ---------------------------------------------------------------------------
-- Sales
-- ---------------------------------------------------------------------------
CREATE TABLE vente (
  vente_id    INT          NOT NULL AUTO_INCREMENT,
  date_vente  DATE,
  prix_vente  DECIMAL(10,2),
  est_neuf    TINYINT      DEFAULT 0,
  client_id   INT,
  produit_id  INT,
  magasin_id  INT          NOT NULL,
  source      CHAR(3),
  PRIMARY KEY (vente_id),
  INDEX idx_date     (date_vente),
  INDEX idx_client   (client_id),
  INDEX idx_produit  (produit_id),
  INDEX idx_magasin  (magasin_id),
  FOREIGN KEY (client_id)  REFERENCES client(client_id),
  FOREIGN KEY (produit_id) REFERENCES produit(produit_id),
  FOREIGN KEY (magasin_id) REFERENCES magasin(magasin_id)
);

-- ---------------------------------------------------------------------------
-- Rentals
-- BuckBoaster does not contribute (no rentals from this source).
-- ---------------------------------------------------------------------------
CREATE TABLE location (
  location_id   INT          NOT NULL AUTO_INCREMENT,
  date_debut    DATE,
  date_fin      DATE,
  prix_jour     DECIMAL(10,2),
  client_id     INT,
  produit_id    INT,
  magasin_id    INT          NOT NULL,
  source        CHAR(3),
  PRIMARY KEY (location_id),
  INDEX idx_date_debut (date_debut),
  INDEX idx_client     (client_id),
  INDEX idx_produit    (produit_id),
  INDEX idx_magasin    (magasin_id),
  FOREIGN KEY (client_id)  REFERENCES client(client_id),
  FOREIGN KEY (produit_id) REFERENCES produit(produit_id),
  FOREIGN KEY (magasin_id) REFERENCES magasin(magasin_id)
);
