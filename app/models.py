
from datetime import datetime

from pydantic import BaseModel, Field


class ItemCreate(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    quantity: int = Field(ge=0)


class ItemSummary(BaseModel):
    id: int
    name: str


class ItemFull(BaseModel):
    id: int
    name: str
    quantity: int
    created_at: datetime
