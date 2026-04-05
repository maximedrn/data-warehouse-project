# Data warehouse project

This project is a data warehouse implementation for a fictional retail company.

_Project made for Master's degree assignment._

## Project description

This project implements a decision support system for the company MoreMovies.
The company acquired three stores:

- MovieMegaMart
- BuckBoaster
- MetroStarlet

Each store has its own information system. The objective is to integrate these systems into a single data warehouse in order to analyze sales and rentals of movies and related products.

Two architectures must be implemented:

- Architecture 1: reporting tool connected directly to the MySQL data warehouse.
- Architecture 2: reporting tool connected to the warehouse through a Mondrian ROLAP server.

## Prerequisites

- [Docker](https://www.docker.com) and Docker Compose
- [Visual Paradigm](https://www.visual-paradigm.com/) or any other ERD tool
- [Python 3.12](https://www.python.org/downloads/)
- [Pyenv](https://github.com/pyenv/pyenv#installation) (optional)
- [Pipx](https://pipx.pypa.io/stable/installation/)
- [Poetry](https://python-poetry.org/docs/#installing-with-pipx) (for Python dependency management)
- [Pandoc](https://pandoc.org) (for Markdown to PDF conversion)
- [Bun](https://bun.sh) (for Mermaid CLI)

## Project structure explanation

- **Adminer**: web-based database management tool to access the MySQL database,
- **Pentaho Data Integration**: ETL tool to extract data from Access databases and load it into MySQL,
- **Pentaho Server**: BI server to host the Mondrian ROLAP server and the reporting client.

### Adminer credentials

| Field    | Value       |
|----------|-------------|
| System   | MySQL       |
| Server   | mysql       |
| Username | root        |
| Password | root        |
| Database | database    |

### Start the infrastructure

```bash
docker compose up -d -f docker-compose.yaml
```

## Microsoft Access Database Loader

This inner project is a Python script to load the Access databases into MySQL.

```bash
# Install Python 3.12.12 with pyenv.
pyenv install 3.12.12

# Set virtual environment in project folder, instead of global user folder.
poetry config virtualenvs.in-project true

# Install project dependencies and activate environment.
poetry install
poetry shell

# Run the script to load the Access databases into MySQL.
python main.py \
  --mysql-url "<MYSQL_URL>" \
  --directory "<MDB_DIRECTORY>"
```

## Markdown to PDF converter

This inner project is a Python script to convert Markdown files to PDF using Pandoc and LaTeX.

```bash
# Install Python 3.12.12 with pyenv.
pyenv install 3.12.12

# Set virtual environment in project folder, instead of global user folder.
poetry config virtualenvs.in-project true

# Install project dependencies and activate environment.
poetry install
poetry shell

# Install mermaid CLI with Bun.
bun install -g @mermaid-js/mermaid-cli

# Run the script to convert a Markdown file to PDF.
python main.py \
  --input "<INPUT_MARKDOWN_FILE>" \
  --output "<OUTPUT_PDF_FILE>" \
  --cls "<LATEX_CLASS_FILE>"
```
