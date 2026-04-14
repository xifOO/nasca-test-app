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

poetry install

poetry run uvicorn app.main:app --host 0.0.0.0 --port 5000 --reload
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
| `DELETE` | `/api/users/{id}` | Удалить пользователя | `user_id` (path) | `200`, `404` | `{"message": "User deleted"}` |

# Пример запроса

```bash
curl -X POST http://localhost:5000/api/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice", "email": "alice@example.com", "age": 30}'
```
---

### Bash-скрипт диагностики

Скрипт scripts/server-info.sh собирает информацию о системе, проверяет ресурсы, статус Docker и доступность HTTP-эндпоинтов. 
Работает на Linux/macOS.

# Использование

```bash
# Диагностика сервера без проверки сервисов
./scripts/server-info.sh

# С проверкой конкретных health-эндпоинтов
./scripts/server-info.sh http://localhost:5000/health http://localhost:8080/health
```

---

### Тестирование
Запускайте pytest из корня проекта, чтобы корректно разрешались импорты app.*.
```bash
# Запуск всех тестов с подробным выводом
poetry run python -m pytest -v
```

---

### Структура проекта

| Файл / Директория | Назначение |
|:---|:---|
| `app/main.py` | Определение маршрутов, логика CRUD, инициализация FastAPI |
| `app/schema.py` | Pydantic-модели для валидации запросов и ответов |
| `app/tests/test_app.py` | Интеграционные тесты с `TestClient` и `pytest` |
| `scripts/server-info.sh` | Скрипт: системная информация + healthcheck |
| `Dockerfile` | Многоэтапная сборка: `builder` → `development` |
| `docker-compose.yml` | Запуск приложения с healthcheck, портами и логированием |
| `pyproject.toml` | Зависимости (`fastapi`, `uvicorn`, `pytest`), конфиг Poetry |
| `.github/workflows/ci.yml` | CI-пайплайн: линтинг → тесты → сборка образа → healthcheck |

---

## Troubleshooting

| Проблема | Возможная причина | Решение |
|:---|:---|:---|
| `ModuleNotFoundError: No module named 'main'` при запуске тестов | Запуск не из корня проекта | Запускайте `poetry run python -m pytest` из корня.|
| `date: illegal option -- %3N` в bash-скрипте на macOS | `%3N` (миллисекунды) не поддерживается в BSD `date` | Скрипт использует автодетект. Обновите до последней версии или замените на `date +%s` |
| Порт `5000` already in use | Другой процесс занимает порт | Найдите: `lsof -i :5000` → `kill -9 <PID>`. Или измените порт в `docker-compose.yml` |
