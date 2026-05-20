-- =============================================================================
-- Q1 — Top Movies by Monthly Revenue
-- Source  : agg_ventes_mois_produit  (pre-computed aggregate)
-- Display : bar chart (Metabase)
-- Purpose : Show film sales revenue per movie per month, ordered to expose
--           the top-earning titles each period.
--
-- Columns returned:
--   Periode   — "YYYY-MM" label for the time axis
--   Film      — movie title (from dim_produit)
--   CA_EUR    — total sales revenue in € for that movie in that month
--   Nb_Ventes — number of sale transactions
--
-- Note: WHERE type_produit = 'film' excludes gadget sales from the ranking.
-- =============================================================================
SELECT
    CONCAT (a.annee, '-', LPAD (a.mois, 2, '0')) AS Periode,
    p.titre AS Film,
    a.ca_total AS CA_EUR,
    a.nb_ventes AS Nb_Ventes
FROM
    agg_ventes_mois_produit a
    JOIN dim_produit p ON p.produit_id = a.produit_id
WHERE
    a.type_produit = 'film'
ORDER BY
    a.annee,
    a.mois,
    a.ca_total DESC