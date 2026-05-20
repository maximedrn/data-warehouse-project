"""Pydantic models for HTTP request and response bodies."""

from enum import Enum

from pydantic import BaseModel, ConfigDict, Field


# pylint: disable=too-few-public-methods
class QuestionConfig(BaseModel):  # type: ignore[explicit-any,misc,unused-ignore]
    """A Metabase question definition loaded from questions.toml.

    :param str name: Display name of the question.
    :param str display: Visualization type (bar, line, table, etc.).
    :param str filename: SQL file name inside the questions directory.
    """

    name: str
    display: str
    filename: str


class QuestionsToml(BaseModel):  # type: ignore[explicit-any,misc,unused-ignore]
    """Parsed structure of questions.toml.

    :param list[QuestionConfig] questions: Ordered list of questions.
    """

    questions: list[QuestionConfig] = Field(default_factory=list)


class MetabaseCredentials(BaseModel):  # type: ignore[explicit-any,misc,unused-ignore]
    """Credentials payload for POST /api/session.

    :param str username: Admin email address.
    :param str password: Admin password.
    """

    username: str
    password: str


class MetabaseSetupUser(BaseModel):  # type: ignore[explicit-any,misc,unused-ignore]
    """User block inside the POST /api/setup payload.

    :param str email: Admin email address.
    :param str password: Admin password.
    :param str first_name: Admin first name.
    :param str last_name: Admin last name.
    :param str site_name: Site name shown in the Metabase UI.
    """

    email: str
    password: str
    first_name: str
    last_name: str
    site_name: str


class MetabaseSetupPreferences(BaseModel):  # type: ignore[explicit-any,misc,unused-ignore]
    """Preferences block inside the POST /api/setup payload.

    :param str site_name: Site name shown in the Metabase UI.
    :param bool allow_tracking: Whether to allow anonymous usage tracking.
    """

    site_name: str
    allow_tracking: bool


class MetabaseSetupRequest(BaseModel):  # type: ignore[explicit-any,misc,unused-ignore]
    """Payload for POST /api/setup (first-run only).

    :param str token: Setup token from /api/session/properties.
    :param MetabaseSetupUser user: Admin user details.
    :param None database: No initial database (added separately).
    :param MetabaseSetupPreferences prefs: UI preferences.
    """

    token: str
    user: MetabaseSetupUser
    database: None = None
    prefs: MetabaseSetupPreferences


class MetabaseDatabaseDetails(BaseModel):  # type: ignore[explicit-any,misc,unused-ignore]
    """Connection details block inside POST /api/database.

    :param str host: MySQL hostname.
    :param int port: MySQL port.
    :param str dbname: MySQL database name.
    :param str user: MySQL username.
    :param str password: MySQL password.
    :param bool ssl: Whether to use SSL.
    """

    host: str
    port: int
    dbname: str
    user: str
    password: str
    ssl: bool = False


class DatabaseEngine(str, Enum):
    """Database engine identifiers accepted by POST /api/database."""

    MYSQL = "mysql"


class MetabaseDatabaseCreate(BaseModel):  # type: ignore[explicit-any,misc,unused-ignore]
    """Payload for POST /api/database.

    :param DatabaseEngine engine: Database engine identifier.
    :param str name: Display name for the database in Metabase.
    :param MetabaseDatabaseDetails details: Connection parameters.
    """

    engine: DatabaseEngine
    name: str
    details: MetabaseDatabaseDetails


class CardNativeQuery(BaseModel):  # type: ignore[explicit-any,misc,unused-ignore]
    """Native SQL query block inside a card's dataset_query.

    :param str query: Raw SQL query string.
    """

    query: str


class QueryType(str, Enum):
    """Query type values for a Metabase card's dataset_query."""

    NATIVE = "native"


class CardDatasetQuery(BaseModel):  # type: ignore[explicit-any,misc,unused-ignore]
    """dataset_query block for a native SQL card.

    :param QueryType type: Query type (native = raw SQL, no visual builder).
    :param int database: Metabase database ID.
    :param CardNativeQuery native: The native query payload.
    """

    type: QueryType
    database: int
    native: CardNativeQuery


class CardCreate(BaseModel):  # type: ignore[explicit-any,misc,unused-ignore]
    """Payload for POST /api/card.

    :param str name: Display name of the question.
    :param str display: Visualization type (bar, line, table, etc.).
    :param CardDatasetQuery dataset_query: The query definition.
    :param dict[str, object] visualization_settings: Chart/table settings.
    """

    name: str
    display: str
    dataset_query: CardDatasetQuery
    visualization_settings: dict[str, object] = Field(default_factory=dict)


class DashboardCreate(BaseModel):  # type: ignore[explicit-any,misc,unused-ignore]
    """Payload for POST /api/dashboard.

    :param str name: Dashboard display name.
    :param str description: Short description shown in Metabase.
    """

    name: str
    description: str


class DashboardCard(BaseModel):  # type: ignore[explicit-any,misc,unused-ignore]
    """A single card entry inside PUT /api/dashboard/{id}/cards.

    :param int id: Client-side temporary ID (negative integer).
    :param int card_id: Metabase card (question) ID.
    :param int row: Grid row position.
    :param int col: Grid column position.
    :param int size_x: Width in grid units.
    :param int size_y: Height in grid units.
    """

    id: int
    card_id: int
    row: int
    col: int
    size_x: int
    size_y: int


class DashboardCardsUpdate(BaseModel):  # type: ignore[explicit-any,misc,unused-ignore]
    """Payload for PUT /api/dashboard/{id}/cards.

    :param list[DashboardCard] cards: All cards to place on the dashboard.
    """

    cards: list[DashboardCard]


class PentahoConnectionCreate(BaseModel):  # type: ignore[explicit-any,misc,unused-ignore]
    """Payload for POST /pentaho/.../connection/add.

    Field aliases map Python snake_case names to the camelCase keys expected
    by the Pentaho REST API. Use :meth:`model_dump(by_alias=True)` when
    serializing.

    :param str name: Connection display name.
    :param str driver_class: JDBC driver class name.
    :param str url: JDBC connection URL.
    :param str username: Database username.
    :param str password: Database password.
    :param int max_active: Maximum active connections in the pool.
    :param int max_idle: Maximum idle connections.
    :param int min_idle: Minimum idle connections.
    :param int max_wait: Maximum wait time in milliseconds.
    :param str db_type: Database type string recognized by Pentaho.
    :param str port: Database port as a string.
    :param str hostname: Database hostname.
    :param str database_name: Database (schema) name.
    :param str access_type: Access mode, always "NATIVE" for direct JDBC.
    """

    model_config = ConfigDict(populate_by_name=True)

    name: str
    driver_class: str = Field(alias="driverClass")
    url: str
    username: str
    password: str
    max_active: int = Field(alias="maxActive", default=20)
    max_idle: int = Field(alias="maxIdle", default=10)
    min_idle: int = Field(alias="minIdle", default=0)
    max_wait: int = Field(alias="maxWait", default=10000)
    db_type: str = Field(alias="dbType")
    port: str
    hostname: str
    database_name: str = Field(alias="databaseName")
    access_type: str = Field(alias="accessType", default="NATIVE")


class PentahoAuthForm(BaseModel):  # type: ignore[explicit-any,misc,unused-ignore]
    """Form payload for POST /pentaho/j_spring_security_check.

    Spring Security expects these exact field names as form-encoded keys.

    :param str j_username: Admin username.
    :param str j_password: Admin password.
    :param str locale: Locale sent alongside credentials (default en_US).
    """

    j_username: str
    j_password: str
    locale: str = "en_US"


class PentahoMondrianUpload(BaseModel):  # type: ignore[explicit-any,misc,unused-ignore]
    """Form payload for POST .../mondrian/postAnalysis (multipart).

    Field aliases map to the camelCase keys expected by the Pentaho REST API.
    Use :meth:`model_dump(by_alias=True)` when passing as ``data=``.

    :param str catalog_name: Mondrian catalog display name.
    :param str datasource_name: JDBC connection name used by the catalog.
    :param str overwrite: Pass "true" to replace an existing schema.
    :param str xmla_enabled_flag: Expose catalog via the XML/A protocol.
    :param str parameters: DataSource info string (e.g. "DataSource=<name>").
    :param str datasource_info: Duplicate of parameters; required by the API.
    """

    model_config = ConfigDict(populate_by_name=True)

    catalog_name: str = Field(alias="catalogName")
    datasource_name: str = Field(alias="datasourceName")
    overwrite: str = "true"
    xmla_enabled_flag: str = Field(alias="xmlaEnabledFlag", default="true")
    parameters: str
    datasource_info: str = Field(alias="datasourceInfo")


class MetabaseHealthStatus(str, Enum):
    """Health status values returned by GET /api/health."""

    OK = "ok"
    DEGRADED = "degraded"
    UNHEALTHY = "unhealthy"


class MetabaseHealthResponse(BaseModel):  # type: ignore[explicit-any,misc,unused-ignore]
    """Response body from GET /api/health."""

    status: MetabaseHealthStatus


class MetabaseSessionResponse(BaseModel):  # type: ignore[explicit-any,misc,unused-ignore]
    """Response body from POST /api/session."""

    id: str | None = None


class MetabaseSetupPropertiesResponse(BaseModel):  # type: ignore[explicit-any,misc,unused-ignore]
    """Relevant fields from GET /api/session/properties."""

    setup_token: str = Field(alias="setup-token", default="")


class MetabaseDatabaseItem(BaseModel):  # type: ignore[explicit-any,misc,unused-ignore]
    """A single database entry from GET /api/database."""

    id: int
    name: str


class MetabaseDatabaseListResponse(BaseModel):  # type: ignore[explicit-any,misc,unused-ignore]
    """Response body from GET /api/database."""

    data: list[MetabaseDatabaseItem] = Field(default_factory=list)


class MetabaseIdResponse(BaseModel):  # type: ignore[explicit-any,misc,unused-ignore]
    """Minimal response carrying only an id field (cards, dashboards, etc.)."""

    id: int


class MetabaseDashboardItem(BaseModel):  # type: ignore[explicit-any,misc,unused-ignore]
    """A single dashboard entry from GET /api/dashboard."""

    id: int
    name: str


class PentahoConnectionItem(BaseModel):  # type: ignore[explicit-any,misc,unused-ignore]
    """A single connection entry from GET .../connection/list."""

    name: str


class PentahoConnectionListResponse(BaseModel):  # type: ignore[explicit-any,misc,unused-ignore]
    """Response body from GET .../connection/list."""

    database_connections: list[PentahoConnectionItem] = Field(
        alias="databaseConnections", default_factory=list
    )
