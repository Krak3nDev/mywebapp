import logging
from pathlib import Path

from fastapi import FastAPI
from fastapi.templating import Jinja2Templates

from app.config import Settings, load_settings
from app.handlers import register_exception_handlers
from app.init_routers import init_routers
from app.lifespan import lifespan

_TEMPLATES_DIR = Path(__file__).parent / "templates"


def create_app(settings: Settings | None = None) -> FastAPI:
    cfg = settings or load_settings()
    logging.basicConfig(
        level=cfg.log.level,
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )
    app = FastAPI(title="mywebapp", lifespan=lifespan)
    app.state.settings = cfg
    app.state.templates = Jinja2Templates(directory=str(_TEMPLATES_DIR))
    init_routers(app)
    register_exception_handlers(app)
    return app
