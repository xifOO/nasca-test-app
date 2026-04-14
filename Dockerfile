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

RUN poetry install --no-root --no-interaction --no-ansi --only main

FROM python-base AS development

ENV APP_ENV=development

RUN groupadd -g 1500 appuser && \
    useradd -m -u 1500 -g appuser appuser

COPY --from=builder-base $POETRY_HOME $POETRY_HOME

WORKDIR /app

COPY --chown=appuser:appuser pyproject.toml poetry.lock* README.md ./

RUN poetry install --no-root --no-interaction --no-ansi --with test

COPY --chown=appuser:appuser . .

USER appuser

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c \
    "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')" \
    || exit 1
 
CMD ["uvicorn", "app:main", "--host", "0.0.0.0", "--port", "5000", "--reload"]

FROM python-base AS prod
 
ENV APP_ENV=prod
 
RUN groupadd -g 1500 appuser && \
    useradd -m -u 1500 -g appuser appuser
 
COPY --from=builder-base $VENV_PATH $VENV_PATH
 
WORKDIR /app
 
COPY --chown=appuser:appuser app.py ./
 
USER appuser
 
EXPOSE 5000
 
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c \
    "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')" \
    || exit 1
 
CMD ["uvicorn", "app:main", "--host", "0.0.0.0", "--port", "5000"]