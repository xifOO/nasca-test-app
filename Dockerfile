FROM python:3.12-slim-bullseye AS python-base

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    POETRY_HOME="/opt/poetry" \
    POETRY_VIRTUALENVS_IN_PROJECT=true \
    POETRY_NO_INTERACTION=1 \
    VENV_PATH="/app/.venv"

ENV PATH="$POETRY_HOME/bin:$VENV_PATH/bin:$PATH"

FROM python-base AS builder-base

RUN apt-get update && \
    apt-get install --no-install-recommends -y curl build-essential && \
    rm -rf /var/lib/apt/lists/*

RUN curl -sSL https://install.python-poetry.org | python3 -

WORKDIR /app
COPY pyproject.toml poetry.lock* ./

RUN poetry config virtualenvs.create true && \
    poetry install --no-root --no-interaction --no-ansi

FROM python-base AS development

ENV APP_ENV=development

RUN groupadd -g 1500 poetry && \
    useradd -m -u 1500 -g poetry poetry

COPY --from=builder-base $POETRY_HOME $POETRY_HOME

ENV PATH="$POETRY_HOME/bin:/usr/local/bin:$PATH"

WORKDIR /app

COPY --chown=poetry:poetry pyproject.toml poetry.lock* README.md ./

RUN poetry config virtualenvs.create false && \
    poetry install --no-root --no-interaction --no-ansi

COPY --chown=poetry:poetry . .

USER poetry

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "5000", "--reload"]

HEALTHCHECK --interval=10s --timeout=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')" || exit 1