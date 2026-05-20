FROM mwalbeck/python-poetry:2-3.14

WORKDIR /app

COPY pyproject.toml poetry.lock* ./

RUN poetry install --no-root

COPY . .

CMD ["poetry", "run", "python", "main.py"]
