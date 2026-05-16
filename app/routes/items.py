
from fastapi import APIRouter, HTTPException, Request, Response, status
from fastapi.encoders import jsonable_encoder
from fastapi.responses import JSONResponse

from app import repo
from app.deps import ConnDep, PrefersHtmlDep, TemplatesDep
from app.models import ItemCreate, ItemFull, ItemSummary

items_router = APIRouter(tags=["items"])


@items_router.get(
    "/items",
    responses={200: {"model": list[ItemSummary]}},
)
async def list_items(
    request: Request,
    conn: ConnDep,
    templates: TemplatesDep,
    prefers_html: PrefersHtmlDep,
) -> Response:
    items = await repo.list_items(conn)
    if prefers_html:
        return templates.TemplateResponse(
            request, "items_list.html.j2", {"items": items}
        )
    return JSONResponse(content=jsonable_encoder(items))


@items_router.post(
    "/items",
    status_code=status.HTTP_201_CREATED,
    responses={201: {"model": ItemFull}},
)
async def create_item(payload: ItemCreate, conn: ConnDep) -> Response:
    created = await repo.create_item(conn, payload)
    return JSONResponse(
        content=jsonable_encoder(created),
        status_code=status.HTTP_201_CREATED,
        headers={"Location": f"/items/{created.id}"},
    )


@items_router.get(
    "/items/{item_id}",
    responses={200: {"model": ItemFull}, 404: {"description": "item not found"}},
)
async def get_item(
    item_id: int,
    request: Request,
    conn: ConnDep,
    templates: TemplatesDep,
    prefers_html: PrefersHtmlDep,
) -> Response:
    item = await repo.get_item(conn, item_id)
    if item is None:
        raise HTTPException(status_code=404, detail="item not found")
    if prefers_html:
        return templates.TemplateResponse(
            request, "item_detail.html.j2", {"item": item}
        )
    return JSONResponse(content=jsonable_encoder(item))
