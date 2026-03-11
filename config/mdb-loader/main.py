#!/usr/bin/env python3
"""Main script for loading .mdb files into MySQL using Polars."""

from argparse import ArgumentParser, Namespace
from collections.abc import Callable
from dataclasses import dataclass
from logging import INFO, Logger, basicConfig, getLogger
from pathlib import Path
from typing import cast

import polars_access_mdbtools as _polars_access_mdbtools
from polars import DataFrame, Decimal, Float64, read_database_uri
from polars._typing import PolarsDataType
from polars_access_mdbtools import (
    _convert_data_type_from_access_to_polars,
    list_table_names,
    read_table,
)
from pydantic import BaseModel
from wrapt import patch_function_wrapper

basicConfig(level=INFO, format="%(asctime)s %(levelname)s %(message)s")
logger: Logger = getLogger(__name__)


@patch_function_wrapper(  # type: ignore[misc,unused-ignore]
    _polars_access_mdbtools.__name__,
    _convert_data_type_from_access_to_polars.__name__,
)
def _patch_decimal(
    wrapped: Callable[[str], PolarsDataType | None],
    _instance: object,
    args: tuple[str],
    kwargs: dict[str, PolarsDataType | None],
) -> PolarsDataType | None:
    """Patch the decimal data type conversion to replace Decimal with Float64.

    :param Callable[[str], PolarsDataType | None] wrapped: The original
        function being wrapped.
    :param object _instance: The instance to which the wrapped function is
        bound (if any).
    :param tuple[str] args: The positional arguments passed to the wrapped
        function.
    :param dict[str, PolarsDataType | None] kwargs: The keyword arguments
        passed to the wrapped function.
    :returns: The result of the wrapped function, with Decimal replaced by
        Float64.
    :rtype: PolarsDataType | None
    """
    result: PolarsDataType | None = wrapped(*args, **kwargs)
    return Float64 if result == Decimal else result


@dataclass(frozen=True, init=True, kw_only=True)
class MySQLUrl:
    """Represents a MySQL connection URL.

    :param url: The MySQL connection URL.
    """

    url: str

    @property
    def sqlalchemy_url(self) -> str:
        """Convert the MySQL URL to a SQLAlchemy-compatible URL.

        :returns: The SQLAlchemy-compatible MySQL connection URL.
        :rtype: str
        """
        return self.url.replace("mysql://", "mysql+pymysql://")


class Arguments(Namespace):  # pylint: disable=too-few-public-methods
    """Defines the expected command-line arguments.

    :param str mysql_url: SQLAlchemy connection URL for MySQL.
    :param str directory: Directory containing .mdb files.
    """

    mysql_url: str
    directory: str


class RowCount(BaseModel):  # type: ignore[explicit-any,misc,unused-ignore]
    """Defines the expected structure of the row count query result.

    :param int n: Number of rows in the table.
    """

    n: int


@dataclass(frozen=True, kw_only=True)
class MdbLoaderConfig:
    """Configuration for the MDB loader.

    :param MySQLUrl mysql_url: SQLAlchemy connection URL for the MySQL
        database.
    :param str directory: Directory containing .mdb files.
    """

    mysql_url: MySQLUrl
    directory: str


class MdbLoader:
    """Loads Microsoft Access (.mdb) files into a MySQL database.

    Each table in a .mdb file is loaded into MySQL as {prefix}_{table}.
    Tables already containing data are skipped (idempotent).
    """

    def __init__(self, configuration: MdbLoaderConfig) -> None:
        """Initialize the MdbLoader with the given configuration.

        :param MdbLoaderConfig configuration: Configuration for the loader.
        :returns: None
        :rtype: None
        """
        self.__configuration: MdbLoaderConfig = configuration

    def is_already_loaded(self, target_table: str) -> bool:
        """Check whether a MySQL table already contains data.

        :param str target_table: Name of the target MySQL table.
        :returns: True if the table exists and contains at least one row.
        :rtype: bool
        """
        try:
            data_frame: DataFrame = read_database_uri(
                f"SELECT COUNT(*) as n FROM `{target_table}`",
                uri=self.__configuration.mysql_url.url,
            )
            rows: list[dict[str, int]] = cast(
                list[dict[str, int]], data_frame.to_dicts()
            )
            return RowCount.model_validate(rows[0]).n > 0
        except Exception as exception:  # pylint: disable=broad-exception-caught
            logger.error(
                "An error occurred while checking if table is already "
                "loaded into MySQL: %s",
                exception,
            )
            return False

    def load_table(self, prefix: str, mdb_path: str, table: str) -> None:
        """Load a single .mdb table into MySQL.

        The target table name is {prefix}_{table}. Skips the table if it
        already contains data.

        :param str prefix: Prefix for the MySQL table name.
        :param str mdb_path: Path to the .mdb file.
        :param str table: Name of the source table in the .mdb file.
        :returns: None
        :rtype: None
        """
        target: str = f"{prefix}_{table}"
        if self.is_already_loaded(target):
            logger.info("Skipping %s, table is already loaded.", target)
            return

        data_frame: DataFrame = read_table(mdb_path, table)
        data_frame.write_database(
            target,
            connection=self.__configuration.mysql_url.sqlalchemy_url,
            if_table_exists="replace",
        )
        logger.info("Loaded %d rows into %s.", len(data_frame), target)

    def load_mdb(self, prefix: str, mdb_path: str) -> None:
        """Load all tables from a single .mdb file into MySQL.

        :param str prefix: Prefix to use for all MySQL table names.
        :param str mdb_path: Path to the .mdb file.
        :returns: None
        :rtype: None
        """
        logger.info("Loading %s from '%s'.", prefix, mdb_path)
        for table in list_table_names(mdb_path):
            self.load_table(prefix, mdb_path, table)
        logger.info("Finished loading %s.", prefix)

    def run(self) -> None:
        """Execute the full loading pipeline for all configured .mdb files.

        :returns: None
        :rtype: None
        """
        logger.info("Loading MDB files.")
        files: list[Path] = list(
            Path(self.__configuration.directory).glob("*.mdb")
        )
        logger.info("Found %d .mdb files to load.", len(files))
        for mdb_file in files:
            self.load_mdb(mdb_file.stem, mdb_file.as_posix())
        logger.info("Finished loading MDB files.")


def parse_args() -> Arguments:
    """Parse command-line arguments.

    :returns: Parsed arguments.
    :rtype: Arguments
    """
    parser: ArgumentParser = ArgumentParser(
        description="Load .mdb files into MySQL."
    )
    parser.add_argument(
        "--mysql-url",
        required=True,
        type=str,
        help="SQLAlchemy connection URL for MySQL.",
    )
    parser.add_argument(
        "--directory",
        required=True,
        type=str,
        help="Directory containing MDB files.",
    )
    return parser.parse_args(namespace=Arguments())


if __name__ == "__main__":
    arguments: Arguments = parse_args()
    config: MdbLoaderConfig = MdbLoaderConfig(
        mysql_url=MySQLUrl(url=arguments.mysql_url),
        directory=arguments.directory,
    )
    MdbLoader(config).run()
