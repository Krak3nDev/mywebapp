
from psycopg_pool import AsyncConnectionPool

from app.config import DbConfig


def create_pool(cfg: DbConfig) -> AsyncConnectionPool:
    return AsyncConnectionPool(
        conninfo=cfg.dsn,
        min_size=cfg.pool_min,
        max_size=cfg.pool_max,
        open=False,
    )


async def ping(pool: AsyncConnectionPool) -> None:
    async with pool.connection() as conn, conn.cursor() as cur:
        await cur.execute("SELECT 1")
        await cur.fetchone()
