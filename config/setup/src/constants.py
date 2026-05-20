"""Project-wide constants grouped by domain."""


# pylint: disable=too-few-public-methods
class MetabaseRoutes:
    """Metabase REST API endpoint paths and dashboard card grid layout."""

    HEALTH = "/api/health"
    SESSION = "/api/session"
    SESSION_PROPS = "/api/session/properties"
    SETUP = "/api/setup"
    DATABASE = "/api/database"
    CARD = "/api/card"
    DASHBOARD = "/api/dashboard"
    DASHBOARD_CARDS = "/api/dashboard/{dash_id}/cards"
    LAYOUT: tuple[dict[str, int], ...] = (
        {"row": 0, "col": 0, "size_x": 12, "size_y": 6},
        {"row": 6, "col": 0, "size_x": 12, "size_y": 6},
        {"row": 12, "col": 0, "size_x": 6, "size_y": 6},
        {"row": 12, "col": 6, "size_x": 6, "size_y": 6},
        {"row": 18, "col": 0, "size_x": 12, "size_y": 6},
    )


class PentahoRoutes:
    """Pentaho Server REST API endpoint paths."""

    HOME = "/pentaho/"
    AUTH = "/pentaho/j_spring_security_check"
    CONN_LIST = "/pentaho/plugin/data-access/api/connection/list"
    CONN_ADD = "/pentaho/plugin/data-access/api/connection/add"
    MONDRIAN = "/pentaho/plugin/data-access/api/mondrian/postAnalysis"


class SqlFiles:
    """SQL and TOML file names read from the setup directories."""

    ROLAP_SCHEMA = "05_rolap_warehouse.sql"
    ROLAP_LOAD = "06_load_rolap_from_raw.sql"
    QUESTIONS_TOML = "questions.toml"


class RolapTables:
    """ROLAP table names used for idempotency checks and DDL cleanup."""

    ORPHANED: tuple[str, ...] = (
        "metrostarlet_actor",
        "moviemegamart_moviecopy",
        "metrostarlet_acts_in",
        "metrostarlet_copy_for_sale",
        "buckboaster_actor",
        "buckboaster_msyscompacterror",
        "buckboaster_actsin",
        "buckboaster_movie",
        "buckboaster_sale_item",
    )
    DIM_TEMPS = "dim_temps"
    FACT_SALES = "fait_ventes"
    FACT_RENTS = "fait_locations"
    AGGREGATE_SALES = "agg_ventes_mois_magasin"
    # buckboaster_movie is in ORPHANED (dropped before mdb-loader) so it is
    # guaranteed to be absent until mdb-loader re-creates it.  Using it as the
    # probe ensures the wait loop does not exit prematurely when
    # buckboaster_customer already has rows from a previous run.
    SOURCE_PROBE = "buckboaster_movie"
