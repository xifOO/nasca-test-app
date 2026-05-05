.PHONY: help install lint test run server-info docker-build docker-run compose-up compose-down compose-logs

APP_NAME := simple-app
IMAGE    := $(APP_NAME):latest
PORT     := 5000
SCRIPTS  := scripts

help: ## Показать доступные цели создания
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

install: ## Установите проект и протестируйте зависимости с помощью Poetry.
	poetry install --with test --no-root

lint: ## Запустить линтеры
	poetry run ruff check .
	shellcheck app/$(SCRIPTS)/*.sh 

test: ## Запустить тесты
	poetry run python -m pytest -v

run: ## Запустить FastAPI приложение локально
	poetry run uvicorn app.main:app --host 0.0.0.0 --port $(PORT) --reload

server-info: ## Запустить диагностику сервера, используя локальный API проверки работоспособности
	app/$(SCRIPTS)/server-info.sh http://localhost:$(PORT)/health

docker-build: ## Создать Docker образ
	docker build -t $(IMAGE) .

docker-run: docker-build ## Запустить Docker образ локально
	docker run --rm -p $(PORT):$(PORT) --name $(APP_NAME) $(IMAGE)

compose-up: ## Запустить сервисы Docker Compose
	docker compose up -d --build

compose-down: ## Остановить сервисы Docker Compose
	docker compose down

compose-logs: ## Вывести логи Docker Compose
	docker compose logs -f
