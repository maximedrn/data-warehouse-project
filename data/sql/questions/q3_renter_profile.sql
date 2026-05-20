-- =============================================================================
-- Q3 — Renter Profile (Average Age by Gender)
-- Source  : fait_locations, dim_client
-- Display : bar chart (Metabase)
-- Purpose : Describe the profile of clients who rent movies, broken down by
--           gender, with average age and rental volume.
--
-- Age reference date: 2010-01-01 (dim_client.age is pre-computed at ETL load time).
-- BuckBoaster clients are not included because BB has no rental activity.
--
-- Columns returned:
--   Genre                — 'Femme' or 'Homme'
--   Age_Moyen            — average age (rounded to 1 decimal) among renters
--   Nb_Clients_Distincts — number of unique clients who rented at least once
--   Nb_Locations         — total number of rental transactions
-- =============================================================================
SELECT
    CASE c.genre
        WHEN 'F' THEN 'Femme'
        ELSE 'Homme'
    END AS Genre,
    ROUND(AVG(c.age), 1) AS Age_Moyen,
    COUNT(DISTINCT f.client_id) AS Nb_Clients_Distincts,
    COUNT(*) AS Nb_Locations
FROM
    fait_locations f
    JOIN dim_client c ON c.client_id = f.client_id
GROUP BY
    c.genre
ORDER BY
    c.genre DESC