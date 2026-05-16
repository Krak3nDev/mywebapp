from collections.abc import AsyncIterator
from typing import Annotated

from fastapi import Depends, Request
from fastapi.templating import Jinja2Templates
from psycopg import AsyncConnection
from psycopg_pool import AsyncConnectionPool

from app.negotiation import wants_html


def get_pool(request: Request) -> AsyncConnectionPool:
    pool: AsyncConnectionPool = request.app.state.pool
    return pool


async def get_conn(
    pool: Annotated[AsyncConnectionPool, Depends(get_pool)],
) -> AsyncIterator[AsyncConnection]:
    async with pool.connection() as conn:
        yield conn


def get_templates(request: Request) -> Jinja2Templates:
    templates: Jinja2Templates = request.app.state.templates
    return templates


def prefers_html(request: Request) -> bool:
    return wants_html(request)


PoolDep = Annotated[AsyncConnectionPool, Depends(get_pool)]
ConnDep = Annotated[AsyncConnection, Depends(get_conn)]
TemplatesDep = Annotated[Jinja2Templates, Depends(get_templates)]
PrefersHtmlDep = Annotated[bool, Depends(prefers_html)]
