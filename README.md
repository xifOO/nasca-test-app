# Simple App
REST API на **FastAPI** для управления пользователями. Приложение упаковано в Docker, покрыто автотестами, сопровождается bash-скриптом для диагностики.

---

## Описание

Проект представляет собой сервис с CRUD-операциями над пользователями:

- Асинхронный сервер на `FastAPI` + `Uvicorn`
- Контейнеризация через `Docker` и `docker-compose`
- Интеграционные тесты на `pytest`
- Bash-скрипт для сбора метрик и проверки health-эндпоинтов
  
---

## Требования

- **Python** `3.12+`
- **Poetry** `2.0+` (для локальной разработки)
- **Docker** & **Docker Compose** `v2+`

---

## Cтарт

### Локальный запуск

```bash
git clone <repo-url>
cd nasca-test-app

poetry install --with test

poetry run uvicorn app.main:app --host 0.0.0.0 --port 5000 --reload
```

Или через `Makefile`:

```bash
make install
make run
```

### Запуск через docker compose
```bash
docker compose up -d --build

docker compose logs -f app

docker compose down
```
---

## API Endpoints


| Метод | Путь | Описание | Параметры | Статусы | Пример ответа |
|:---|:---|:---|:---|:---|:---|
| `GET` | `/` | Приветственное сообщение | — | `200` | `{"message": "Hello, world!"}` |
| `GET` | `/health` | Проверка работоспособности | — | `200` | `{"status": "ok"}` |
| `GET` | `/api/users` | Список всех пользователей | — | `200` | `{"users": [...]}` |
| `POST` | `/api/users` | Создать нового пользователя | `name`, `email`, `age` | `201`, `422` | `{"id": "...", "name": "..."}` |
| `GET` | `/api/users/{id}` | Получить пользователя по ID | `user_id` (path) | `200`, `404` | `{"id": "...", "name": "..."}` |
| `DELETE` | `/api/users/{id}` | Удалить пользователя | `user_id` (path) | `200`, `404` | `{"message": "Пользователь удален"}` |

# Пример запроса

```bash
curl -X POST http://localhost:5000/api/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice", "email": "alice@example.com", "age": 30}'
```
---

### Bash-скрипт диагностики

Скрипт `app/scripts/server-info.sh` собирает информацию о системе, проверяет ресурсы, статус Docker и доступность HTTP-эндпоинтов. Результат одновременно выводится в консоль и записывается в лог-файл с timestamp в имени. По умолчанию логи сохраняются в `/tmp`, каталог можно переопределить через `LOG_DIR`.
Работает на Linux/macOS.

# Использование

```bash
# Диагностика сервера без проверки сервисов
app/scripts/server-info.sh

# С проверкой конкретных health-эндпоинтов
app/scripts/server-info.sh http://localhost:5000/health http://localhost:8080/health

# С записью логов в свой каталог
LOG_DIR=/var/log app/scripts/server-info.sh http://localhost:5000/health
```

---

### Тестирование
Запускайте pytest из корня проекта, чтобы корректно разрешались импорты app.*.
```bash
# Запуск всех тестов с подробным выводом
poetry run python -m pytest -v
```

### Ansible развертывание

#### Структура 

```
ansible/
├── inventory.ini        # адрес и пользователь целевого сервера
├── playbook.yml         # точка входа
├── group_vars/
│   └── all.yml          # переменные: порт, образ, окружение
└── roles/
    ├── docker/          # установка Docker
    │   ├── tasks/main.yml
    │   └── handlers/main.yml
    └── app/             # деплой приложения
        ├── tasks/main.yml
        └── templates/
            ├── docker-compose.yml.j2
            └── .env.j2
```

#### Запуск

```bash
# проверить связь с сервером
ansible -i ansible/inventory.ini webservers -m ping

# развернуть приложение
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml

# Dry-run
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --check

# С verbose логированием
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml -vvv
```

---

### Структура проекта

| Файл / Директория | Назначение |
|:---|:---|
| `app/main.py` | Определение маршрутов, логика CRUD, инициализация FastAPI |
| `app/schema.py` | Pydantic-модели для валидации запросов и ответов |
| `app/tests/test_app.py` | Интеграционные тесты с `TestClient` и `pytest` |
| `app/scripts/server-info.sh` | Скрипт: системная информация + healthcheck |
| `Dockerfile` | Многоэтапная сборка: `builder-base` → `development` / `production` |
| `docker-compose.yaml` | Запуск приложения с healthcheck, портами и логированием |
| `pyproject.toml` | Зависимости (`fastapi`, `uvicorn`, `pytest`), конфиг Poetry |
| `ansible/` | Роли и playbook для автоматизированного деплоя |
| `.github/workflows/build.yml` | CI-пайплайн: линтинг → тесты → сборка образа → healthcheck |

---

## Troubleshooting

| Проблема | Возможная причина | Решение |
|:---|:---|:---|
| `ModuleNotFoundError: No module named 'main'` при запуске тестов | Запуск не из корня проекта | Запускайте `poetry run python -m pytest` из корня.|
| `date: illegal option -- %3N` в bash-скрипте на macOS | `%3N` (миллисекунды) не поддерживается в BSD `date` | Скрипт использует автодетект. Обновите до последней версии или замените на `date +%s` |
| Порт `5000` already in use | Другой процесс занимает порт | Найдите: `lsof -i :5000` → `kill -9 <PID>`. Или измените порт в `docker-compose.yml` |
| `No package matching 'docker-ce' is available` в Ansible | Неверная архитектура в apt repo (`aarch64` вместо `arm64`) | В `docker/tasks/main.yml` используйте: `arch={{ 'arm64' if ansible_architecture == 'aarch64' else 'amd64' }}` |
