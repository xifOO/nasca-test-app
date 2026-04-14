import uuid

from fastapi import FastAPI, HTTPException

from schema import User, UserCreate


app = FastAPI()
users_db = {}


@app.get("/")
def root():
    return {"message": "Hello, world!"}


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/api/users")
def get_users():
    return {"users": list(users_db.values())}


@app.post("/api/users", status_code=201)
def create_user(user: UserCreate):
    user_id = str(uuid.uuid4())
    new_user = User(id=user_id, **user.model_dump())
    users_db[user_id] = new_user.model_dump()
    return new_user


@app.get("/api/users/{user_id}")
def get_user(user_id: str):
    user = users_db.get(user_id)
    if not user:
        raise HTTPException(status_code=404, detail=f"Пользователь с id={user_id} не найден.")
    return user


@app.delete("/api/users/{user_id}", status_code=200)
def delete_user(user_id: str):
    user = users_db.pop(user_id, None)
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь с id={user_id} не найден.")
    return {"message": "User deleted"}

