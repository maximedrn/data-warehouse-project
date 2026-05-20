-- =============================================================================
-- Q4 — Most Rented Movies by Store
-- Source  : agg_locations_mois_produit_magasin  (pre-computed aggregate)
-- Display : table (Metabase)
-- Purpose : Show the rental count and revenue for each movie, broken down by
--           store and month, to identify the most popular titles per location.
--
-- Columns returned:
--   Magasin      — store name
--   Periode      — "YYYY-MM" label for the time axis
--   Film         — movie title (from dim_produit)
--   Nb_Locations — number of rental transactions for that movie/store/month
--   CA_EUR       — total rental revenue in € for that movie/store/month
--
-- Sorted by (year, month, store, nb_locations DESC) to put top titles first.
-- =============================================================================
SELECT
    m.nom AS Magasin,
    CONCAT (a.annee, '-', LPAD (a.mois, 2, '0')) AS Periode,
    p.titre AS Film,
    a.nb_locations AS Nb_Locations,
    a.ca_total AS CA_EUR
FROM
    agg_locations_mois_produit_magasin a
    JOIN dim_produit p ON p.produit_id = a.produit_id
    JOIN dim_magasin m ON m.magasin_id = a.magasin_id
ORDER BY
    a.annee,
    a.mois,
    m.nom,
    a.nb_locations DESC