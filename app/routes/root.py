
from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse

from app.deps import TemplatesDep

root_router = APIRouter(tags=["root"])

BUSINESS_ENDPOINTS: tuple[tuple[str, str], ...] = (
    ("GET", "/items"),
    ("POST", "/items"),
    ("GET", "/items/<id>"),
)


@root_router.get("/", include_in_schema=False, response_class=HTMLResponse)
async def root(request: Request, templates: TemplatesDep) -> HTMLResponse:
    return templates.TemplateResponse(
        request, "index.html.j2", {"endpoints": BUSINESS_ENDPOINTS}
    )
