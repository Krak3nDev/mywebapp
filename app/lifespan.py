
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.db import create_pool


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    settings = app.state.settings
    pool = create_pool(settings.db)
    await pool.open()
    app.state.pool = pool
    try:
        yield
    finally:
        await pool.close()
