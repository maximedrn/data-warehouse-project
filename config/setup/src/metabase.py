"""Metabase HTTP client — account, database, questions, and dashboard setup."""

from logging import Logger, getLogger
from pathlib import Path
from time import sleep
from typing import Self, cast

from httpx import Client, Response
from pydantic import TypeAdapter
from tomllib import load

from src.config import MetabaseConfig, MysqlConfig
from src.constants import MetabaseRoutes, SqlFiles
from src.models import (
    CardCreate,
    CardDatasetQuery,
    CardNativeQuery,
    DashboardCard,
    DashboardCardsUpdate,
    DashboardCreate,
    DatabaseEngine,
    MetabaseCredentials,
    MetabaseDashboardItem,
    MetabaseDatabaseCreate,
    MetabaseDatabaseDetails,
    MetabaseDatabaseItem,
    MetabaseDatabaseListResponse,
    MetabaseHealthResponse,
    MetabaseHealthStatus,
    MetabaseIdResponse,
    MetabaseSessionResponse,
    MetabaseSetupPreferences,
    MetabaseSetupPropertiesResponse,
    MetabaseSetupRequest,
    MetabaseSetupUser,
    QueryType,
    QuestionConfig,
    QuestionsToml,
)

logger: Logger = getLogger(__name__)

# GET /api/dashboard returns a bare JSON array, not a {"data": [...]} envelope,
# so a TypeAdapter is needed instead of a plain BaseModel.
_DASHBOARD_LIST_ADAPTER: TypeAdapter[list[MetabaseDashboardItem]] = (
    TypeAdapter(list[MetabaseDashboardItem])
)


class _MetabaseApi:  # pylint: disable=too-few-public-methods
    """Typed HTTP wrapper for authenticated Metabase API calls."""

    def __init__(self, base_url: str, token: str) -> None:
        """Create an authenticated httpx client for the given session token.

        :param str base_url: Metabase base URL.
        :param str token: Active Metabase session token.
        :returns: None
        :rtype: None
        """
        self._client: Client = Client(
            base_url=base_url,
            headers={"X-Metabase-Session": token},
        )

    def __enter__(self) -> Self:
        """Return self for use as a context manager.

        :returns: This instance.
        :rtype: _MetabaseApi
        """
        return self

    def __exit__(self, *_: object) -> None:
        """Close the underlying HTTP client.

        :returns: None
        :rtype: None
        """
        self._client.close()

    def list_databases(self) -> list[MetabaseDatabaseItem]:
        """Return all databases registered in Metabase.

        :returns: List of database items.
        :rtype: list[MetabaseDatabaseItem]
        """
        response: Response = self._client.get(MetabaseRoutes.DATABASE)
        return MetabaseDatabaseListResponse.model_validate(
            cast(dict[str, object], response.json())
        ).data

    def add_database(self, payload: MetabaseDatabaseCreate) -> int:
        """Register a new database and return its Metabase ID.

        :param MetabaseDatabaseCreate payload: Database creation payload.
        :returns: New database ID.
        :rtype: int
        """
        response: Response = self._client.post(
            MetabaseRoutes.DATABASE,
            json=cast(dict[str, object], payload.model_dump()),
        )
        return MetabaseIdResponse.model_validate(
            cast(dict[str, object], response.json())
        ).id

    def list_dashboards(self) -> list[MetabaseDashboardItem]:
        """Return all dashboards registered in Metabase.

        :returns: List of dashboard items.
        :rtype: list[MetabaseDashboardItem]
        """
        response: Response = self._client.get(MetabaseRoutes.DASHBOARD)
        return _DASHBOARD_LIST_ADAPTER.validate_python(
            cast(dict[str, object], response.json())
        )

    def create_dashboard(self, payload: DashboardCreate) -> int:
        """Create a new dashboard and return its    Metabase ID.

        :param DashboardCreate payload: Dashboard creation payload.
        :returns: New dashboard ID.
        :rtype: int
        """
        response: Response = self._client.post(
            MetabaseRoutes.DASHBOARD,
            json=cast(dict[str, object], payload.model_dump()),
        )
        return MetabaseIdResponse.model_validate(
            cast(dict[str, object], response.json())
        ).id

    def create_card(self, payload: CardCreate) -> int:
        """Create a native SQL question card and return its Metabase ID.

        :param CardCreate payload: Card creation payload.
        :returns: New card ID.
        :rtype: int
        """
        response: Response = self._client.post(
            MetabaseRoutes.CARD,
            json=cast(dict[str, object], payload.model_dump()),
        )
        return MetabaseIdResponse.model_validate(
            cast(dict[str, object], response.json())
        ).id

    def set_dashboard_cards(
        self, dash_id: int, payload: DashboardCardsUpdate
    ) -> None:
        """Place cards on a dashboard, replacing any existing layout.

        :param int dash_id: Target dashboard ID.
        :param DashboardCardsUpdate payload: Cards placement payload.
        :returns: None
        :rtype: None
        """
        url: str = MetabaseRoutes.DASHBOARD_CARDS.format(dash_id=dash_id)
        self._client.put(
            url, json=cast(dict[str, object], payload.model_dump())
        )


class MetabaseClient:  # pylint: disable=too-few-public-methods
    """Configures Metabase: admin account, database, questions, and dashboard.

    All operations are idempotent — already-completed steps are skipped.
    """

    def __init__(
        self,
        config: MetabaseConfig,
        mysql: MysqlConfig,
        questions_directory: Path,
    ) -> None:
        """Initialize the MetabaseClient.

        :param MetabaseConfig config: Metabase service configuration.
        :param MysqlConfig mysql: MySQL connection configuration.
        :param Path questions_directory: Directory with question SQL files and
            TOML.
        :returns: None
        :rtype: None
        """
        self.__config: MetabaseConfig = config
        self.__mysql: MysqlConfig = mysql
        self.__questions_directory: Path = questions_directory

    def _wait(self) -> None:
        """Block until the Metabase health endpoint returns status=ok.

        :returns: None
        :rtype: None
        """
        logger.info("Waiting for Metabase...")
        while True:
            try:
                # A new client per attempt: Metabase may not be routable yet.
                with Client() as client:
                    response: Response = client.get(
                        f"{self.__config.url}{MetabaseRoutes.HEALTH}",
                        timeout=10,  # Avoids hanging on a slow start.
                    )
                    health: MetabaseHealthResponse = (
                        MetabaseHealthResponse.model_validate(
                            cast(dict[str, object], response.json())
                        )
                    )
                    if health.status == MetabaseHealthStatus.OK:
                        return logger.info("Metabase ready.")
            except (OSError, TimeoutError) as exception:
                logger.warning("Metabase not ready: %s", exception)
            sleep(10)

    def _login_or_setup(self) -> str:
        """Authenticate or run first-time Metabase setup.

        Tries to log in first; falls back to /api/setup on the very first
        invocation when no admin account exists yet.

        :returns: Active Metabase session token.
        :rtype: str
        """
        credentials: MetabaseCredentials = MetabaseCredentials(
            username=self.__config.admin_email,
            password=self.__config.admin_password,
        )
        with Client(base_url=self.__config.url) as client:
            # Try the normal login path first; only the first boot needs setup.
            response: Response = client.post(
                MetabaseRoutes.SESSION,
                json=cast(dict[str, object], credentials.model_dump()),
            )
            if response.is_success:
                session: MetabaseSessionResponse = (
                    MetabaseSessionResponse.model_validate(
                        cast(dict[str, object], response.json())
                    )
                )
                if session.id:
                    logger.info("Metabase already configured, logged in.")
                    return session.id

            logger.info("Running Metabase first-time setup...")
            # The setup token is a one-time value exposed before any admin
            # account exists; it is consumed by POST /api/setup.
            props: MetabaseSetupPropertiesResponse = (
                MetabaseSetupPropertiesResponse.model_validate(
                    cast(
                        dict[str, object],
                        client.get(MetabaseRoutes.SESSION_PROPS).json(),
                    )
                )
            )
            # Derive a display name from the email local-part (e.g. "Admin").
            first_name: str = self.__config.admin_email.split("@")[
                0
            ].capitalize()
            setup: MetabaseSetupRequest = MetabaseSetupRequest(
                token=props.setup_token,
                user=MetabaseSetupUser(
                    email=self.__config.admin_email,
                    password=self.__config.admin_password,
                    first_name=first_name,
                    last_name=self.__config.site_name,
                    site_name=self.__config.site_name,
                ),
                prefs=MetabaseSetupPreferences(
                    site_name=self.__config.site_name,
                    allow_tracking=False,
                ),
            )
            client.post(
                MetabaseRoutes.SETUP,
                json=cast(dict[str, object], setup.model_dump()),
            )
            logger.info("Metabase admin account created.")

            # Re-login after setup to obtain a valid session token.
            login: Response = client.post(
                MetabaseRoutes.SESSION,
                json=cast(dict[str, object], credentials.model_dump()),
            )
            return (
                MetabaseSessionResponse.model_validate(
                    cast(dict[str, object], login.json())
                ).id
                or ""
            )

    def _ensure_database(self, api: _MetabaseApi) -> int:
        """Add the ROLAP MySQL database to Metabase if not already present.

        :param _MetabaseApi api: Authenticated Metabase API client.
        :returns: Metabase database ID.
        :rtype: int
        """
        # Idempotent: return the existing ID without re-registering.
        for database in api.list_databases():
            if database.name == self.__config.db_name:
                logger.info(
                    "Metabase database '%s' exists (id=%d), skipping.",
                    database.name,
                    database.id,
                )
                return database.id

        payload: MetabaseDatabaseCreate = MetabaseDatabaseCreate(
            engine=DatabaseEngine.MYSQL,
            name=self.__config.db_name,
            details=MetabaseDatabaseDetails(
                host=self.__mysql.host,
                port=self.__mysql.port,
                dbname=self.__mysql.rolap_database,
                user=self.__mysql.user,
                password=self.__mysql.password,
            ),
        )
        database_id: int = api.add_database(payload)
        logger.info(
            "Metabase database '%s' added (id=%d).",
            self.__config.db_name,
            database_id,
        )
        return database_id

    def _load_questions(self) -> list[QuestionConfig]:
        """Load question definitions from questions.toml.

        :returns: List of question configurations.
        :rtype: list[QuestionConfig]
        """
        toml_path: Path = self.__questions_directory / SqlFiles.QUESTIONS_TOML
        with toml_path.open("rb") as file:
            return QuestionsToml.model_validate(
                cast(dict[str, object], load(file))
            ).questions

    def _create_card(
        self,
        api: _MetabaseApi,
        question: QuestionConfig,
        db_id: int,
    ) -> int:
        """Create a native SQL question card in Metabase.

        :param _MetabaseApi api: Authenticated Metabase API client.
        :param QuestionConfig question: Question metadata.
        :param int db_id: Metabase database ID for the query.
        :returns: Created card ID.
        :rtype: int
        """
        sql: str = (self.__questions_directory / question.filename).read_text(
            encoding="utf-8"
        )
        payload: CardCreate = CardCreate(
            name=question.name,
            display=question.display,
            dataset_query=CardDatasetQuery(
                type=QueryType.NATIVE,  # Raw SQL; bypasses the visual builder.
                database=db_id,
                native=CardNativeQuery(query=sql),
            ),
        )
        return api.create_card(payload)

    def _ensure_dashboard(self, api: _MetabaseApi, db_id: int) -> None:
        """Create the analytics dashboard with all questions if not present.

        :param _MetabaseApi api: Authenticated Metabase API client.
        :param int db_id: Metabase database ID.
        :returns: None
        :rtype: None
        """
        # Idempotent: skip creation if the dashboard was already created.
        for dashboard in api.list_dashboards():
            if dashboard.name == self.__config.dashboard_name:
                logger.info(
                    "Dashboard '%s' already exists (id=%s), skipping.",
                    self.__config.dashboard_name,
                    dashboard.id,
                )
                return

        questions: list[QuestionConfig] = self._load_questions()
        logger.info("Creating %d Metabase questions...", len(questions))
        card_ids: list[int] = [
            self._create_card(api, q, db_id) for q in questions
        ]
        logger.info("Questions created (ids: %s).", card_ids)

        dashboard_id: int = api.create_dashboard(
            DashboardCreate(
                name=self.__config.dashboard_name,
                description=(f"{len(questions)} ROLAP analyzes"),
            )
        )
        api.set_dashboard_cards(
            dashboard_id,
            DashboardCardsUpdate(
                cards=[
                    # Metabase requires temporary negative IDs for new cards.
                    DashboardCard(id=-(i + 1), card_id=card_id, **layout)
                    for i, (card_id, layout) in enumerate(
                        zip(card_ids, MetabaseRoutes.LAYOUT, strict=False)
                    )
                ]
            ),
        )
        logger.info(
            "Dashboard '%s' created (id=%s).",
            self.__config.dashboard_name,
            dashboard_id,
        )

    def configure(self) -> None:
        """Run full Metabase configuration, idempotent across restarts.

        :returns: None
        :rtype: None
        """
        self._wait()
        session: str = self._login_or_setup()
        # Share one authenticated session across all subsequent API calls.
        with _MetabaseApi(self.__config.url, session) as api:
            database_id: int = self._ensure_database(api)
            self._ensure_dashboard(api, database_id)
        logger.info("Metabase configuration complete.")
