from typing import Optional

from pydantic import BaseModel


class UserCreate(BaseModel):
    name: str
    email: str
    age: Optional[int] = None


class User(BaseModel):
    id: str
    name: str
    email: str
    age: Optional[int] = None
