"""Settings and typed configuration dataclasses."""

from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlparse

from pydantic_settings import BaseSettings, SettingsConfigDict


# pylint: disable=too-few-public-methods
class Settings(BaseSettings):  # type: ignore[explicit-any,misc,unused-ignore]
    """Application settings loaded from environment variables or .env file."""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    mysql_url: str
    mysql_rolap_database: str
    metabase_url: str
    metabase_admin_email: str
    metabase_admin_password: str
    metabase_db_name: str
    metabase_dashboard_name: str
    metabase_site_name: str
    pentaho_url: str
    pentaho_admin_user: str
    pentaho_admin_password: str
    pentaho_connection_name: str
    pentaho_catalog_name: str
    setup_sql_dir: Path
    setup_mondrian_dir: Path
    setup_questions_dir: Path


@dataclass(frozen=True, kw_only=True)
class MysqlConfig:
    """MySQL connection parameters.

    :param str host: MySQL server hostname.
    :param int port: MySQL server port.
    :param str user: MySQL username.
    :param str password: MySQL password.
    :param str database: Raw source database name.
    :param str rolap_database: ROLAP target database name.
    """

    host: str
    port: int
    user: str
    password: str
    database: str
    rolap_database: str

    @classmethod
    def from_url(cls, url: str, rolap_database: str) -> "MysqlConfig":
        """Parse a MySQL connection URL into a MysqlConfig.

        :param str url: MySQL connection URL (mysql://user:pass@host:port/db).
        :param str rolap_database: Name of the ROLAP target database.
        :returns: Parsed MySQL configuration.
        :rtype: MysqlConfig
        """
        parsed = urlparse(url)
        return cls(
            host=parsed.hostname or "mysql",
            port=parsed.port or 3306,
            user=parsed.username or "root",
            password=parsed.password or "",
            database=(parsed.path or "/").lstrip("/"),
            rolap_database=rolap_database,
        )

    @property
    def sqlalchemy_url(self) -> str:
        """Build a SQLAlchemy-compatible connection URL (no default database).

        :returns: mysql+pymysql://user:pass@host:port/ URL string.
        :rtype: str
        """
        return (
            f"mysql+pymysql://{self.user}:{self.password}"
            f"@{self.host}:{self.port}/"
        )


@dataclass(frozen=True, kw_only=True)
class MetabaseConfig:
    """Metabase service configuration.

    :param str url: Metabase base URL.
    :param str admin_email: Admin account email address.
    :param str admin_password: Admin account password.
    :param str db_name: Display name for the ROLAP database in Metabase.
    :param str dashboard_name: Display name for the auto-created dashboard.
    :param str site_name: Metabase site name used during first-run setup.
    """

    url: str
    admin_email: str
    admin_password: str
    db_name: str
    dashboard_name: str
    site_name: str


@dataclass(frozen=True, kw_only=True)
class PentahoConfig:
    """Pentaho Server configuration.

    :param str url: Pentaho base URL.
    :param str admin_user: Admin username.
    :param str admin_password: Admin password.
    :param str connection_name: JDBC connection display name.
    :param str catalog_name: Mondrian OLAP catalog name.
    """

    url: str
    admin_user: str
    admin_password: str
    connection_name: str
    catalog_name: str


@dataclass(frozen=True, kw_only=True)
class SetupConfig:
    """Top-level configuration for the setup orchestrator.

    :param MysqlConfig mysql: MySQL connection configuration.
    :param MetabaseConfig metabase: Metabase service configuration.
    :param PentahoConfig pentaho: Pentaho server configuration.
    :param Path sql_directory: Directory containing SQL initialization files.
    :param Path mondrian_directory: Directory containing the Mondrian XML
        schema.
    :param Path questions_directory: Directory with question SQL files and
        TOML.
    """

    mysql: MysqlConfig
    metabase: MetabaseConfig
    pentaho: PentahoConfig
    sql_directory: Path
    mondrian_directory: Path
    questions_directory: Path
