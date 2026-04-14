.PHONY: help install lint test run server-info docker-build docker-run compose-up compose-down compose-logs

APP_NAME := simple-app
IMAGE    := $(APP_NAME):latest
PORT     := 5000
SCRIPTS  := scripts

help: 
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

install: 
	poetry install --with dev

lint:
	poetry run ruff check .
	shellcheck app/$(SCRIPTS)/*.sh || true

test: 
	poetry run python -m pytest -v

run: 
	poetry run uvicorn app.main:app --host 0.0.0.0 --port $(PORT) --reload

server-info:
	./$(SCRIPTS)/server-info.sh http://localhost:$(PORT)/health

docker-build: 
	docker build -t $(IMAGE) .

docker-run: docker-build 
	docker run --rm -p $(PORT):$(PORT) --name $(APP_NAME) $(IMAGE)

compose-up: 
	docker compose up -d --build

compose-down:
	docker compose down

compose-logs:
	docker compose logs -f