-- =============================================================================
-- Q2 — Monthly Revenue by Store
-- Source  : agg_ventes_mois_magasin  (pre-computed aggregate)
-- Display : line chart (Metabase)
-- Purpose : Compare sales revenue trends across the three stores month by month.
--
-- Columns returned:
--   Periode    — "YYYY-MM" label for the time axis
--   Magasin    — store name (BuckBoaster / MetroStarlet / MovieMegaMart)
--   CA_EUR     — total sales revenue in € for that store in that month
--   Nb_Ventes  — number of sale transactions
--   Nb_Clients — number of distinct clients who purchased something
-- =============================================================================
SELECT
    CONCAT (a.annee, '-', LPAD (a.mois, 2, '0')) AS Periode,
    m.nom AS Magasin,
    a.ca_total AS CA_EUR,
    a.nb_ventes AS Nb_Ventes,
    a.nb_clients AS Nb_Clients
FROM
    agg_ventes_mois_magasin a
    JOIN dim_magasin m ON m.magasin_id = a.magasin_id
ORDER BY
    a.annee,
    a.mois,
    m.nom