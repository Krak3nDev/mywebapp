
import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_list_items_empty_returns_json_array(client: AsyncClient) -> None:
    r = await client.get("/items", headers={"Accept": "application/json"})
    assert r.status_code == 200
    assert r.headers["content-type"].startswith("application/json")
    assert r.json() == []


@pytest.mark.asyncio
async def test_create_and_get_roundtrip(client: AsyncClient) -> None:
    create = await client.post(
        "/items",
        headers={"Content-Type": "application/json", "Accept": "application/json"},
        json={"name": "bolt", "quantity": 42},
    )
    assert create.status_code == 201
    body = create.json()
    assert body["name"] == "bolt"
    assert body["quantity"] == 42
    new_id = body["id"]
    assert create.headers["location"] == f"/items/{new_id}"

    fetched = await client.get(f"/items/{new_id}", headers={"Accept": "application/json"})
    assert fetched.status_code == 200
    assert fetched.json()["id"] == new_id


@pytest.mark.asyncio
async def test_get_unknown_id_returns_404(client: AsyncClient) -> None:
    r = await client.get("/items/9999", headers={"Accept": "application/json"})
    assert r.status_code == 404


@pytest.mark.asyncio
async def test_invalid_json_returns_422(client: AsyncClient) -> None:
    r = await client.post(
        "/items",
        headers={"Content-Type": "application/json", "Accept": "application/json"},
        content=b"{not json",
    )
    assert r.status_code == 422


@pytest.mark.asyncio
async def test_negative_quantity_returns_422(client: AsyncClient) -> None:
    r = await client.post(
        "/items",
        headers={"Content-Type": "application/json", "Accept": "application/json"},
        json={"name": "x", "quantity": -1},
    )
    assert r.status_code == 422


@pytest.mark.asyncio
async def test_blank_name_returns_422(client: AsyncClient) -> None:
    r = await client.post(
        "/items",
        headers={"Content-Type": "application/json", "Accept": "application/json"},
        json={"name": "", "quantity": 1},
    )
    assert r.status_code == 422
