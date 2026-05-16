
import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_alive_returns_ok(client: AsyncClient) -> None:
    r = await client.get("/health/alive")
    assert r.status_code == 200
    assert r.text == "OK"


@pytest.mark.asyncio
async def test_ready_returns_ok_when_db_up(client: AsyncClient) -> None:
    r = await client.get("/health/ready")
    assert r.status_code == 200
    assert r.text == "OK"


@pytest.mark.asyncio
async def test_ready_returns_500_when_db_down(dead_client: AsyncClient) -> None:
    r = await dead_client.get("/health/ready")
    assert r.status_code == 500
    assert "db unavailable" in r.text
