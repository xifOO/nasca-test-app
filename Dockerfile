FROM python:3.12-slim-bullseye AS python-base

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_NO_CACHE_DIR=1 \
    POETRY_VERSION=2.1.3 \
    POETRY_VIRTUALENVS_IN_PROJECT=true \
    POETRY_NO_INTERACTION=1 \
    VENV_PATH="/app/.venv"

ENV PATH="/usr/local/bin:$VENV_PATH/bin:$PATH"

WORKDIR /app

FROM python-base AS builder-base

RUN apt-get update && \
    apt-get install --no-install-recommends -y build-essential && \
    rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir "poetry==$POETRY_VERSION"

COPY pyproject.toml poetry.lock* ./

RUN poetry install --only main --no-root --no-ansi

FROM builder-base AS development

ENV APP_ENV=development

RUN groupadd -g 1500 appuser && \
    useradd -m -u 1500 -g appuser appuser

COPY README.md ./
RUN poetry install --with test --no-root --no-ansi

COPY . .
RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 5000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "5000", "--reload"]

HEALTHCHECK --interval=10s --timeout=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')" || exit 1

FROM python-base AS production

ENV APP_ENV=production

RUN groupadd -g 1500 appuser && \
    useradd -m -u 1500 -g appuser appuser

COPY --from=builder-base /app/.venv /app/.venv
COPY --chown=appuser:appuser app ./app
COPY --chown=appuser:appuser pyproject.toml README.md ./

USER appuser

EXPOSE 5000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "5000"]

HEALTHCHECK --interval=10s --timeout=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')" || exit 1
