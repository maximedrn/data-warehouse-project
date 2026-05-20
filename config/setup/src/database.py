"""MySQL database client — schema init, data loading, and readiness checks."""

from logging import Logger, getLogger
from pathlib import Path
from time import sleep

from pymysql import connect as pymysql_connect
from pymysql.constants import CLIENT
from sqlalchemy import (
    CursorResult,
    MetaData,
    Table,
    create_engine,
    func,
    select,
    text,
)
from sqlalchemy.engine import Engine
from sqlalchemy.schema import DropTable

from src.config import MysqlConfig
from src.constants import RolapTables, SqlFiles

logger: Logger = getLogger(__name__)


class DatabaseClient:
    """Manages MySQL database initialization and ROLAP data loading.

    Uses SQLAlchemy Core for queries and raw pymysql for multi-statement
    SQL file execution (which requires CLIENT.MULTI_STATEMENTS).
    """

    def __init__(self, config: MysqlConfig) -> None:
        """Initialize the DatabaseClient and create the SQLAlchemy engine.

        :param MysqlConfig config: MySQL connection configuration.
        :returns: None
        :rtype: None
        """
        self.__config: MysqlConfig = config
        self.__engine: Engine = create_engine(config.sqlalchemy_url)

    def _count_rows(self, schema: str, table_name: str) -> int:
        """Count rows in a table using SQLAlchemy Core, returning 0 on error.

        :param str schema: Database (schema) name.
        :param str table_name: Table name.
        :returns: Row count, or 0 if the table does not exist.
        :rtype: int
        """
        try:
            table: Table = Table(table_name, MetaData(), schema=schema)
            with self.__engine.connect() as connection:
                result: CursorResult[tuple[int]] = connection.execute(
                    select(func.count()).select_from(table)
                )
                return int(result.scalar() or 0)
        except Exception as exception:  # pylint: disable=broad-exception-caught
            logger.warning(
                "Error counting rows in %s.%s: %s",
                schema,
                table_name,
                exception,
            )
            return 0

    def _source_ready(self) -> bool:
        """Check whether the mdb-loader source probe table is accessible.

        :returns: True when buckboaster_customer exists and has at least one
            row.
        :rtype: bool
        """
        try:
            table: Table = Table(
                RolapTables.SOURCE_PROBE,
                MetaData(),
                schema=self.__config.database,
            )
            with self.__engine.connect() as connection:
                result: CursorResult[tuple[int]] = connection.execute(
                    select(func.count()).select_from(table)
                )
                return int(result.scalar() or 0) > 0
        except Exception as exception:  # pylint: disable=broad-exception-caught
            logger.warning(
                "Error checking source readiness: %s",
                exception,
            )
            return False

    def _execute_sql_file(self, path: Path) -> None:
        """Execute a multi-statement SQL file via a raw pymysql connection.

        SQLAlchemy does not natively expose CLIENT.MULTI_STATEMENTS, so a
        dedicated pymysql connection is used for SQL files that contain many
        semicolon-separated statements (e.g. 06_load_rolap_from_raw.sql).

        :param Path path: Path to the SQL file.
        :returns: None
        :rtype: None
        """
        sql: str = path.read_text(encoding="utf-8")
        connection = pymysql_connect(
            host=self.__config.host,
            port=self.__config.port,
            user=self.__config.user,
            password=self.__config.password,
            autocommit=True,
            client_flag=CLIENT.MULTI_STATEMENTS,
        )
        try:
            with connection.cursor() as cursor:
                cursor.execute(sql)
                while cursor.nextset():
                    pass
        finally:
            connection.close()

    def wait(self) -> None:
        """Block until MySQL is reachable.

        :returns: None
        :rtype: None
        """
        logger.info("Waiting for MySQL...")
        while True:
            try:
                with self.__engine.connect() as conn:
                    conn.execute(text("SELECT 1"))
                logger.info("MySQL ready.")
                return
            except Exception as exception:  # pylint: disable=broad-exception-caught
                logger.warning(
                    "Error occurred while waiting for MySQL: %s",
                    exception,
                )
                sleep(3)

    def ensure_rolap_schema(self, sql_dir: Path) -> None:
        """Create the db_rolap schema if dim_temps is empty.

        :param Path sql_dir: Directory containing the schema SQL file.
        :returns: None
        :rtype: None
        """
        dimensions: int = self._count_rows(
            self.__config.rolap_database, RolapTables.DIM_TEMPS
        )
        if dimensions > 0:
            logger.info(
                "db_rolap schema already exists (%d rows in %s), skipping.",
                dimensions,
                RolapTables.DIM_TEMPS,
            )
            return
        logger.info("Creating db_rolap schema...")
        self._execute_sql_file(sql_dir / SqlFiles.ROLAP_SCHEMA)
        logger.info("db_rolap schema created.")

    def drop_orphaned_tables(self) -> None:
        """Drop tables whose InnoDB tablespace files are missing.

        Prevents mdb-loader from crashing on orphaned table references
        (MySQL Error 1812). Foreign key checks are disabled for the whole
        batch and unconditionally re-enabled at the end.

        :returns: None
        :rtype: None
        """
        logger.info("Cleaning orphaned tables...")
        schema: str = self.__config.database
        with self.__engine.connect() as connection:
            connection.execute(text("SET FOREIGN_KEY_CHECKS = 0"))
            for table_name in RolapTables.ORPHANED:
                try:
                    table: Table = Table(table_name, MetaData(), schema=schema)
                    connection.execute(DropTable(table, if_exists=True))
                except Exception as exception:  # pylint: disable=broad-exception-caught
                    logger.warning(
                        "Could not drop %s: %s", table_name, exception
                    )
            connection.execute(text("SET FOREIGN_KEY_CHECKS = 1"))
        logger.info("Orphaned tables cleaned.")

    def wait_for_mdb_loader(self) -> None:
        """Wait for mdb-loader to finish populating the source database.

        Skips the wait if ROLAP aggregates are already populated, which
        means a previous successful run can restart instantly.

        :returns: None
        :rtype: None
        """
        aggregates: int = self._count_rows(
            self.__config.rolap_database, RolapTables.AGGREGATE_SALES
        )
        if aggregates > 0:
            logger.info(
                "Aggregates already populated (%d rows), skipping mdb-loader "
                "wait.",
                aggregates,
            )
            return
        logger.info("Waiting for mdb-loader to populate source database...")
        while not self._source_ready():
            logger.info("mdb-loader still running, retrying in 15s...")
            sleep(15)
        logger.info("mdb-loader done.")

    def load_rolap_from_raw(self, sql_dir: Path) -> None:
        """Populate db_rolap from raw Access data if not already loaded.

        :param Path sql_dir: Directory containing the load SQL file.
        :returns: None
        :rtype: None
        """
        database: str = self.__config.rolap_database
        sales: int = self._count_rows(database, RolapTables.FACT_SALES)
        rents: int = self._count_rows(database, RolapTables.FACT_RENTS)
        aggregates: int = self._count_rows(
            database, RolapTables.AGGREGATE_SALES
        )
        if sales > 0 and rents > 0 and aggregates > 0:
            logger.info(
                "db_rolap already loaded (ventes=%d, locations=%d, agg=%d), "
                "skipping.",
                sales,
                rents,
                aggregates,
            )
            return
        logger.info("Loading db_rolap from raw Access data...")
        self._execute_sql_file(sql_dir / SqlFiles.ROLAP_LOAD)
        logger.info("db_rolap loaded.")
