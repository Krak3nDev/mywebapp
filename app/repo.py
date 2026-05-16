from psycopg import AsyncConnection

from app.models import ItemCreate, ItemFull, ItemSummary


async def list_items(conn: AsyncConnection) -> list[ItemSummary]:
    async with conn.cursor() as cur:
        await cur.execute("SELECT id, name FROM items ORDER BY created_at DESC, id DESC")
        rows = await cur.fetchall()
    return [ItemSummary(id=row[0], name=row[1]) for row in rows]


async def create_item(conn: AsyncConnection, data: ItemCreate) -> ItemFull:
    async with conn.cursor() as cur:
        await cur.execute(
            "INSERT INTO items (name, quantity) VALUES (%s, %s) "
            "RETURNING id, name, quantity, created_at",
            (data.name, data.quantity),
        )
        row = await cur.fetchone()
    if row is None:
        raise RuntimeError("INSERT returned no row")
    return ItemFull(id=row[0], name=row[1], quantity=row[2], created_at=row[3])


async def get_item(conn: AsyncConnection, item_id: int) -> ItemFull | None:
    async with conn.cursor() as cur:
        await cur.execute(
            "SELECT id, name, quantity, created_at FROM items WHERE id = %s",
            (item_id,),
        )
        row = await cur.fetchone()
    if row is None:
        return None
    return ItemFull(id=row[0], name=row[1], quantity=row[2], created_at=row[3])
