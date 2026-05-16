
import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_root_returns_html_with_endpoints(client: AsyncClient) -> None:
    r = await client.get("/", headers={"Accept": "text/html"})
    assert r.status_code == 200
    assert r.headers["content-type"].startswith("text/html")
    assert "/items" in r.text
    assert "/health" not in r.text  # business endpoints only


@pytest.mark.asyncio
async def test_root_has_no_inline_js_or_css(client: AsyncClient) -> None:
    r = await client.get("/", headers={"Accept": "text/html"})
    text = r.text.lower()
    assert "<script" not in text
    assert "<style" not in text
