"""Pentaho HTTP client — JDBC connection and Mondrian schema setup."""

from logging import Logger, getLogger
from pathlib import Path
from time import sleep
from typing import cast

from httpx import Client, Response

from src.config import MysqlConfig, PentahoConfig
from src.constants import PentahoRoutes
from src.models import (
    PentahoAuthForm,
    PentahoConnectionCreate,
    PentahoConnectionListResponse,
    PentahoMondrianUpload,
)

logger: Logger = getLogger(__name__)


class PentahoClient:  # pylint: disable=too-few-public-methods
    """Configures Pentaho Server: JDBC connection and Mondrian schema.

    The JDBC connection creation is idempotent (skipped if already present).
    The Mondrian schema is always re-uploaded with overwrite=true to pick up
    any schema changes without manual intervention.
    """

    def __init__(
        self,
        config: PentahoConfig,
        mysql: MysqlConfig,
        mondrian_directory: Path,
    ) -> None:
        """Initialize the PentahoClient.

        :param PentahoConfig config: Pentaho server configuration.
        :param MysqlConfig mysql: MySQL connection configuration.
        :param Path mondrian_directory: Directory containing the Mondrian XML
            schema.
        :returns: None
        :rtype: None
        """
        self.__config: PentahoConfig = config
        self.__mysql: MysqlConfig = mysql
        self.__mondrian_directory: Path = mondrian_directory

    def _wait(self) -> None:
        """Block until Pentaho returns HTTP 200 or 302.

        :returns: None
        :rtype: None
        """
        logger.info("Waiting for Pentaho Server...")
        while True:
            try:
                with Client(follow_redirects=False) as client:
                    response: Response = client.get(
                        f"{self.__config.url}{PentahoRoutes.HOME}",
                        timeout=10.0,
                    )
                    if response.status_code in {200, 302}:
                        logger.info("Pentaho ready.")
                        return
            except (OSError, TimeoutError) as exception:
                logger.warning(
                    "Error occurred while waiting for Pentaho Server: %s",
                    exception,
                )
            sleep(20)

    def _login(self) -> Client:
        """Authenticate with Pentaho and return an authenticated httpx client.

        The returned client stores session cookies for subsequent requests.
        The caller must close it (use try/finally or a context manager).

        :returns: Authenticated httpx.Client with active session cookies.
        :rtype: Client
        """
        client: Client = Client(
            base_url=self.__config.url, follow_redirects=True
        )
        auth: PentahoAuthForm = PentahoAuthForm(
            j_username=self.__config.admin_user,
            j_password=self.__config.admin_password,
        )
        client.post(
            PentahoRoutes.AUTH, data=cast(dict[str, object], auth.model_dump())
        )
        return client

    def _ensure_connection(self, client: Client) -> None:
        """Add the JDBC connection in Pentaho if it does not already exist.

        :param Client client: Authenticated Pentaho httpx client.
        :returns: None
        :rtype: None
        """
        response: Response = client.get(PentahoRoutes.CONN_LIST)
        connection_list: PentahoConnectionListResponse = (
            PentahoConnectionListResponse.model_validate(
                cast(dict[str, object], response.json())
            )
        )
        existing_names: set[str] = {
            connection.name
            for connection in connection_list.database_connections
        }
        if self.__config.connection_name in existing_names:
            logger.info(
                "JDBC connection '%s' already exists, skipping.",
                self.__config.connection_name,
            )
            return

        jdbc_url: str = (
            f"jdbc:mysql://{self.__mysql.host}:{self.__mysql.port}"
            f"/{self.__mysql.rolap_database}"
            "?useSSL=false&allowPublicKeyRetrieval=true"
        )
        payload: PentahoConnectionCreate = PentahoConnectionCreate(
            name=self.__config.connection_name,
            driverClass="com.mysql.jdbc.Driver",
            url=jdbc_url,
            username=self.__mysql.user,
            password=self.__mysql.password,
            dbType="MySQL",
            port=str(self.__mysql.port),
            hostname=self.__mysql.host,
            databaseName=self.__mysql.rolap_database,
        )
        client.post(
            PentahoRoutes.CONN_ADD,
            json=cast(dict[str, object], payload.model_dump(by_alias=True)),
        )
        logger.info(
            "JDBC connection '%s' created.", self.__config.connection_name
        )

    def _upload_mondrian(self, client: Client) -> None:
        """Upload the Mondrian OLAP schema to Pentaho, always overwriting.

        :param Client client: Authenticated Pentaho httpx client.
        :returns: None
        :rtype: None
        """
        mondrian_file: Path = next(self.__mondrian_directory.glob("*.xml"))
        # Both `parameters` and `datasourceInfo` carry the same DataSource
        # string; Pentaho requires both fields to be present.
        datasource_info: str = f"DataSource={self.__config.connection_name}"
        upload: PentahoMondrianUpload = PentahoMondrianUpload(
            catalogName=self.__config.catalog_name,
            datasourceName=self.__config.connection_name,
            parameters=datasource_info,
            datasourceInfo=datasource_info,
        )
        with mondrian_file.open("rb") as file:
            response: Response = client.post(
                PentahoRoutes.MONDRIAN,
                data=cast(dict[str, object], upload.model_dump(by_alias=True)),
                files={
                    "uploadAnalysis": (mondrian_file.name, file, "text/xml")
                },
            )
        logger.info(
            "Mondrian schema uploaded. Response: %s", response.text[:100]
        )

    def configure(self) -> None:
        """Run full Pentaho configuration, idempotent across restarts.

        :returns: None
        :rtype: None
        """
        self._wait()
        client: Client = self._login()
        try:
            self._ensure_connection(client)
            self._upload_mondrian(client)
        finally:
            client.close()
        logger.info("Pentaho configuration complete.")
