
import logging
import re

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse, PlainTextResponse
from psycopg import Error as PsycopgError
from psycopg_pool import PoolClosed, PoolTimeout

from app.config import ConfigError

_logger = logging.getLogger(__name__)
_DSN_PATTERN = re.compile(
    r"(password\s*=\s*\S+|postgresql://[^@\s]+:[^@\s]+@)", re.IGNORECASE
)


def redact(message: str) -> str:
    return _DSN_PATTERN.sub("password=***", message)


async def config_error_handler(_: Request, exc: Exception) -> JSONResponse:
    _logger.error("configuration error: %s", redact(str(exc)))
    return JSONResponse(
        status_code=500, content={"error": "service configuration error"}
    )


async def db_error_handler(_: Request, exc: Exception) -> JSONResponse:
    _logger.error("database error: %s", redact(str(exc)))
    return JSONResponse(status_code=500, content={"error": "database unavailable"})


async def pool_error_handler(_: Request, exc: Exception) -> JSONResponse:
    _logger.error("connection pool error: %s", redact(str(exc)))
    return JSONResponse(status_code=503, content={"error": "service temporarily unavailable"})


async def validation_error_handler(_: Request, exc: Exception) -> JSONResponse:
    details = exc.errors() if isinstance(exc, RequestValidationError) else []
    return JSONResponse(
        status_code=422,
        content={"error": "validation failed", "details": details},
    )


async def not_found_handler(_: Request, __: Exception) -> PlainTextResponse:
    return PlainTextResponse("not found", status_code=404)


def register_exception_handlers(app: FastAPI) -> None:
    app.add_exception_handler(ConfigError, config_error_handler)
    app.add_exception_handler(PsycopgError, db_error_handler)
    app.add_exception_handler(PoolTimeout, pool_error_handler)
    app.add_exception_handler(PoolClosed, pool_error_handler)
    app.add_exception_handler(RequestValidationError, validation_error_handler)
    # int 404 ONLY; do NOT register StarletteHTTPException — it would swallow
    # all 4xx/5xx HTTPExceptions as 404 "not found".
    app.add_exception_handler(404, not_found_handler)
