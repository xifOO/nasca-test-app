.PHONY: help install lint test run server-info docker-build docker-run compose-up compose-down compose-logs ansible-check ansible-dry ansible-run

APP_NAME := simple-app
IMAGE    := $(APP_NAME):latest
PORT     := 5000
SCRIPTS  := scripts

help: ## показать все команды
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

install: ## установить зависимости
	poetry install --with test --no-root

lint: ## проверить качество кода
	poetry run ruff check .
	shellcheck app/$(SCRIPTS)/*.sh 

test: ## запустить тесты
	poetry run python -m pytest -v

run: ## запустить приложение
	poetry run uvicorn app.main:app --host 0.0.0.0 --port $(PORT) --reload

server-info: ## запустить Bash-скрипт диагностики сервера
	app/$(SCRIPTS)/server-info.sh http://localhost:$(PORT)/health

docker-build: ## собрать Docker образ
	docker build -t $(IMAGE) .

docker-run: docker-build ## запустить контейнер
	docker run --rm -p $(PORT):$(PORT) --name $(APP_NAME) $(IMAGE)

compose-up: ## запустить Docker Compose
	docker compose up -d --build

compose-down: ## остановить Docker Compose
	docker compose down

compose-logs: ## просмотреть логи
	docker compose logs -f

ansible-check: ## проверить Ansible playbook
	ansible-playbook --syntax-check -i ansible/inventory.ini ansible/playbook.yml

ansible-dry: ## dry-run Ansible
	ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --check

ansible-run: ## запустить Ansible playbook
	ansible-playbook -i ansible/inventory.ini ansible/playbook.yml