
from fastapi import APIRouter
from fastapi.responses import PlainTextResponse

from app.db import ping
from app.deps import PoolDep

health_router = APIRouter(tags=["health"])


@health_router.get("/health/alive", response_class=PlainTextResponse)
async def alive() -> PlainTextResponse:
    return PlainTextResponse("OK", status_code=200)


@health_router.get("/health/ready", response_class=PlainTextResponse)
async def ready(pool: PoolDep) -> PlainTextResponse:
    try:
        await ping(pool)
    except Exception as exc:
        return PlainTextResponse(
            f"db unavailable: {exc.__class__.__name__}", status_code=500
        )
    return PlainTextResponse("OK", status_code=200)
