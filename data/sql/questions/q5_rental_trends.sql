-- =============================================================================
-- Q5 — Monthly Rental Trends
-- Source  : agg_locations_mois_produit_magasin  (pre-computed aggregate)
-- Display : line chart (Metabase)
-- Purpose : Track overall rental volume and revenue month by month, with a
--           month-over-month percentage change to highlight growth or decline.
--
-- Columns returned:
--   Periode       — "YYYY-MM" label for the time axis
--   Nb_Locations  — total rentals across all stores that month
--   CA_EUR        — total rental revenue in € that month
--   Variation_Pct — month-over-month change in rental count (%)
--
-- CTE breakdown:
--   mensuel   — roll up the aggregate table to (annee, mois) grain
--   avec_var  — add previous month's rental count via LAG window function
-- The first month is excluded (WHERE loc_prec IS NOT NULL) since it has no prior.
-- =============================================================================
WITH
    mensuel AS (
        -- Aggregate across all stores to get a single monthly figure
        SELECT
            annee,
            mois,
            SUM(nb_locations) AS nb_locations,
            SUM(ca_total) AS ca_total
        FROM
            agg_locations_mois_produit_magasin
        GROUP BY
            annee,
            mois
    ),
    avec_var AS (
        -- Attach previous month's rental count for the MoM variation
        SELECT
            *,
            LAG (nb_locations) OVER (
                ORDER BY
                    annee,
                    mois
            ) AS loc_prec
        FROM
            mensuel
    )
SELECT
    CONCAT (annee, '-', LPAD (mois, 2, '0')) AS Periode,
    nb_locations AS Nb_Locations,
    ca_total AS CA_EUR,
    ROUND((nb_locations - loc_prec) / loc_prec * 100, 1) AS Variation_Pct
FROM
    avec_var
WHERE
    loc_prec IS NOT NULL -- skip first month (no previous period to compare)
ORDER BY
    annee,
    mois