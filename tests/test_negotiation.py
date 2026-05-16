
import pytest
from fastapi import Request
from httpx import AsyncClient

from app.negotiation import wants_html


def _request(accept: str | None) -> Request:
    headers = []
    if accept is not None:
        headers.append((b"accept", accept.encode()))
    scope = {
        "type": "http",
        "method": "GET",
        "path": "/",
        "headers": headers,
    }
    return Request(scope)


def test_html_explicit() -> None:
    assert wants_html(_request("text/html")) is True


def test_json_explicit() -> None:
    assert wants_html(_request("application/json")) is False


def test_missing_accept_defaults_to_json() -> None:
    assert wants_html(_request(None)) is False


def test_wildcard_defaults_to_json() -> None:
    assert wants_html(_request("*/*")) is False


def test_html_beats_json_when_q_equal() -> None:
    assert wants_html(_request("application/json, text/html")) is True


def test_higher_q_json_wins() -> None:
    assert wants_html(_request("text/html;q=0.5, application/json;q=0.9")) is False


@pytest.mark.asyncio
async def test_items_html_returns_table(client: AsyncClient) -> None:
    r = await client.get("/items", headers={"Accept": "text/html"})
    assert r.status_code == 200
    assert r.headers["content-type"].startswith("text/html")
    assert "<table" in r.text
    assert "<script" not in r.text.lower()
    assert "<style" not in r.text.lower()


@pytest.mark.asyncio
async def test_items_json_returns_json(client: AsyncClient) -> None:
    r = await client.get("/items", headers={"Accept": "application/json"})
    assert r.status_code == 200
    assert r.headers["content-type"].startswith("application/json")
