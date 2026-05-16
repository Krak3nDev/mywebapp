from collections.abc import AsyncIterator
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.config import DbConfig, LogConfig, ServerConfig, Settings
from app.deps import get_pool
from app.main import create_app


@dataclass
class _Row:
    id: int
    name: str
    quantity: int
    created_at: datetime


class FakeCursor:
    def __init__(self, pool: "FakePool") -> None:
        self._pool = pool
        self._result: list[tuple[Any, ...]] = []

    async def __aenter__(self) -> "FakeCursor":
        return self

    async def __aexit__(self, *exc: Any) -> None:
        return None

    async def execute(self, sql: str, params: tuple[Any, ...] | None = None) -> None:
        sql_l = sql.lower()
        if "select 1" in sql_l:
            self._result = [(1,)]
        elif "select id, name from items" in sql_l:
            self._result = [(r.id, r.name) for r in self._pool.rows]
        elif "insert into items" in sql_l:
            assert params is not None
            name, quantity = params
            row = _Row(
                id=self._pool._next_id,
                name=name,
                quantity=quantity,
                created_at=datetime.now(tz=UTC),
            )
            self._pool._next_id += 1
            self._pool.rows.append(row)
            self._result = [(row.id, row.name, row.quantity, row.created_at)]
        elif "select id, name, quantity, created_at from items where id" in sql_l:
            assert params is not None
            (item_id,) = params
            self._result = [
                (r.id, r.name, r.quantity, r.created_at)
                for r in self._pool.rows
                if r.id == item_id
            ]
        else:
            self._result = []

    async def fetchone(self) -> tuple[Any, ...] | None:
        return self._result[0] if self._result else None

    async def fetchall(self) -> list[tuple[Any, ...]]:
        return list(self._result)


class FakeConn:
    def __init__(self, pool: "FakePool") -> None:
        self._pool = pool

    async def __aenter__(self) -> "FakeConn":
        return self

    async def __aexit__(self, *exc: Any) -> None:
        return None

    def cursor(self) -> FakeCursor:
        return FakeCursor(self._pool)


class FakePool:
    def __init__(self, *, db_up: bool = True) -> None:
        self.rows: list[_Row] = []
        self._next_id = 1
        self.db_up = db_up
        self.opened = False

    async def open(self) -> None:
        self.opened = True

    async def close(self) -> None:
        self.opened = False

    def connection(self) -> FakeConn:
        if not self.db_up:
            raise RuntimeError("simulated db down")
        return FakeConn(self)


def _settings() -> Settings:
    return Settings(
        server=ServerConfig(host="127.0.0.1", port=8080),
        db=DbConfig(
            host="127.0.0.1",
            port=5432,
            name="mywebapp",
            user="mywebapp",
            password="x",
            pool_min=1,
            pool_max=2,
        ),
        log=LogConfig(level="WARNING"),
    )


@pytest.fixture
def app_with_fake_pool() -> tuple[FastAPI, FakePool]:
    pool = FakePool()
    app = create_app(settings=_settings())
    app.dependency_overrides[get_pool] = lambda: pool
    return app, pool


@pytest.fixture
def app_with_dead_pool() -> FastAPI:
    pool = FakePool(db_up=False)
    app = create_app(settings=_settings())
    app.dependency_overrides[get_pool] = lambda: pool
    return app


@pytest.fixture
async def client(app_with_fake_pool: tuple[FastAPI, FakePool]) -> AsyncIterator[AsyncClient]:
    app, _ = app_with_fake_pool
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.fixture
async def dead_client(app_with_dead_pool: FastAPI) -> AsyncIterator[AsyncClient]:
    transport = ASGITransport(app=app_with_dead_pool)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
