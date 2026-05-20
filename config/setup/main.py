#!/usr/bin/env python3
"""Entry point — builds configuration from environment and runs the setup."""

from logging import INFO, basicConfig

from src.config import (
    MetabaseConfig,
    MysqlConfig,
    PentahoConfig,
    Settings,
    SetupConfig,
)
from src.orchestrator import SetupOrchestrator

basicConfig(level=INFO, format="%(asctime)s %(levelname)s %(message)s")

if __name__ == "__main__":
    settings: Settings = Settings()  # type: ignore[call-arg]
    config: SetupConfig = SetupConfig(
        mysql=MysqlConfig.from_url(
            settings.mysql_url, settings.mysql_rolap_database
        ),
        metabase=MetabaseConfig(
            url=settings.metabase_url,
            admin_email=settings.metabase_admin_email,
            admin_password=settings.metabase_admin_password,
            db_name=settings.metabase_db_name,
            dashboard_name=settings.metabase_dashboard_name,
            site_name=settings.metabase_site_name,
        ),
        pentaho=PentahoConfig(
            url=settings.pentaho_url,
            admin_user=settings.pentaho_admin_user,
            admin_password=settings.pentaho_admin_password,
            connection_name=settings.pentaho_connection_name,
            catalog_name=settings.pentaho_catalog_name,
        ),
        sql_directory=settings.setup_sql_dir,
        mondrian_directory=settings.setup_mondrian_dir,
        questions_directory=settings.setup_questions_dir,
    )
    SetupOrchestrator(config).run()
