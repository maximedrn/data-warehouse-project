FROM mwalbeck/python-poetry:2-3.14

# Install mdbtools for reading .mdb files.
RUN apt-get update -q && apt-get install -y -q mdbtools

# Copy the pyproject.toml and poetry.lock files to the container to set up 
# the Python environment.
COPY pyproject.toml poetry.lock* /app/

WORKDIR /app

# Install Python dependencies using Poetry.
RUN poetry install --no-root

# Copy the main script into the container.
COPY main.py .

# Set environment variables for the MySQL connection URL and the directory 
# containing .mdb files.
ARG MYSQL_URL
ARG MDB_DIRECTORY
ENV MYSQL_URL=$MYSQL_URL
ENV MDB_DIRECTORY=$MDB_DIRECTORY

# Run the main script with the provided environment variables.
CMD poetry run python main.py \
    --mysql-url "$MYSQL_URL" \
    --directory "$MDB_DIRECTORY"
