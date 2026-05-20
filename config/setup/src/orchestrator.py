"""Setup orchestrator — coordinates all service configuration steps."""

from logging import Logger, getLogger

from src.config import SetupConfig
from src.database import DatabaseClient
from src.metabase import MetabaseClient
from src.pentaho import PentahoClient

logger: Logger = getLogger(__name__)


class SetupOrchestrator:  # pylint: disable=too-few-public-methods
    """Orchestrates the full MoreMovies DW automated setup pipeline.

    Steps executed in order:
        1. Wait for MySQL; ensure db_rolap schema exists.
        2. Drop orphaned tables (prevents mdb-loader Error 1812).
        3. Wait for mdb-loader to finish loading source data.
        4. Load db_rolap from raw Access data.
        5. Configure Metabase (admin account, database, questions, dashboard).
        6. Configure Pentaho (JDBC connection, Mondrian schema).
    """

    def __init__(self, config: SetupConfig) -> None:
        """Initialize the SetupOrchestrator and all service clients.

        :param SetupConfig config: Full setup configuration.
        :returns: None
        :rtype: None
        """
        self.__config: SetupConfig = config
        self.__database: DatabaseClient = DatabaseClient(config.mysql)
        self.__metabase: MetabaseClient = MetabaseClient(
            config.metabase, config.mysql, config.questions_directory
        )
        self.__pentaho: PentahoClient = PentahoClient(
            config.pentaho, config.mysql, config.mondrian_directory
        )

    def run(self) -> None:
        """Execute all setup steps in sequence.

        :returns: None
        :rtype: None
        """
        self.__database.wait()
        self.__database.ensure_rolap_schema(self.__config.sql_directory)
        self.__database.drop_orphaned_tables()
        self.__database.wait_for_mdb_loader()
        self.__database.load_rolap_from_raw(self.__config.sql_directory)
        self.__metabase.configure()
        self.__pentaho.configure()
        logger.info("Adminer -> http://localhost:8081")
        logger.info("WebSpoon -> http://localhost:8085")
        logger.info("Pentaho -> http://localhost:8083")
        logger.info(
            "Metabase -> http://localhost:8084 (%s)",
            self.__config.metabase.admin_email,
        )
