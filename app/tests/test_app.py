from fastapi.testclient import TestClient
import pytest
from app.main import users_db, app


@pytest.fixture(autouse=True)
def clear_db():
    users_db.clear()
    yield
    users_db.clear()


client = TestClient(app)


def test_root():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"message": "Hello, world!"}


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_create_user_success():
    payload = {"name": "Alice", "email": "alice@example.com", "age": 30}
    response = client.post("/api/users", json=payload)
    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "Alice"
    assert data["email"] == "alice@example.com"
    assert data["age"] == 30
    assert "id" in data


def test_create_user_validation_error():
    payload = {"name": "Bob"}  # email отсутствует
    response = client.post("/api/users", json=payload)
    assert response.status_code == 422


def test_get_user_by_id():
    created = client.post(
        "/api/users", json={"name": "Charlie", "email": "charlie@example.com"}
    )
    user_id = created.json()["id"]
    response = client.get(f"/api/users/{user_id}")
    assert response.status_code == 200
    assert response.json()["id"] == user_id


def test_get_user_not_found():
    response = client.get("/api/users/not-found-id")
    assert response.status_code == 404
    assert response.json()["detail"] == "Пользователь с id=not-found-id не найден."


def test_delete_user_success():
    created = client.post(
        "/api/users", json={"name": "Dave", "email": "dave@example.com"}
    )
    user_id = created.json()["id"]
    response = client.delete(f"/api/users/{user_id}")
    assert response.status_code == 200


def test_delete_user_not_found():
    response = client.delete("/api/users/not-found-id")
    assert response.status_code == 404
