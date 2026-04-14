import logging
import uuid

from fastapi import FastAPI, HTTPException

from app.schema import User, UserCreate

logger = logging.getLogger("app")
handler = logging.StreamHandler()
handler.setFormatter(
    logging.Formatter("%(asctime)s | %(levelname)-8s | %(message)s", datefmt="%H:%M:%S")
)
logger.addHandler(handler)
logger.setLevel(logging.INFO)


app = FastAPI()
users_db = {}


@app.get("/")
def root():
    logger.info("Корневой эндпоинт вызван")
    return {"message": "Hello, world!"}


@app.get("/health")
def health():
    logger.debug("Проверка здоровья")
    return {"status": "ok"}


@app.get("/api/users")
def get_users():
    logger.info(f"GET /api/users | Всего пользователей: {len(users_db)}")
    return {"users": list(users_db.values())}


@app.post("/api/users", status_code=201)
def create_user(user: UserCreate):
    user_id = str(uuid.uuid4())
    new_user = User(id=user_id, **user.model_dump())
    users_db[user_id] = new_user.model_dump()
    logger.info(f"POST /api/users | Создан пользователь: {user_id} ({user.email})")
    return new_user


@app.get("/api/users/{user_id}")
def get_user(user_id: str):
    user = users_db.get(user_id)
    if not user:
        logger.warning(f"GET /api/users/{user_id} | Не найден")
        raise HTTPException(
            status_code=404, detail=f"Пользователь с id={user_id} не найден."
        )
    logger.info(f"GET /api/users/{user_id} | Найден")
    return user


@app.delete("/api/users/{user_id}", status_code=200)
def delete_user(user_id: str):
    user = users_db.pop(user_id, None)
    if not user:
        logger.warning(f"DELETE /api/users/{user_id} | Не найден")
        raise HTTPException(
            status_code=404, detail="Пользователь с id={user_id} не найден."
        )
    logger.info(f"DELETE /api/users/{user_id} | Удален")
    return {"message": "Пользователь удален"}
