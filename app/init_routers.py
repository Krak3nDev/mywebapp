
from fastapi import FastAPI

from app.routes.health import health_router
from app.routes.items import items_router
from app.routes.root import root_router


def init_routers(app: FastAPI) -> None:
    app.include_router(root_router)
    app.include_router(health_router)
    app.include_router(items_router)
