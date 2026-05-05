from typing import Optional

from pydantic import BaseModel, EmailStr


class UserCreate(BaseModel):
    name: str
    email: EmailStr
    age: Optional[int] = None


class User(BaseModel):
    id: str
    name: str
    email: EmailStr
    age: Optional[int] = None
