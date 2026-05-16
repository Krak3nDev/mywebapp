import os
import tomllib
from dataclasses import dataclass
from pathlib import Path
from typing import Any


class ConfigError(Exception):
    pass


@dataclass(frozen=True)
class ServerConfig:
    host: str
    port: int


@dataclass(frozen=True)
class DbConfig:
    host: str
    port: int
    name: str
    user: str
    password: str
    pool_min: int
    pool_max: int

    @property
    def dsn(self) -> str:
        return (
            f"host={self.host} port={self.port} dbname={self.name} "
            f"user={self.user} password={self.password}"
        )


@dataclass(frozen=True)
class LogConfig:
    level: str


@dataclass(frozen=True)
class Settings:
    server: ServerConfig
    db: DbConfig
    log: LogConfig


DEFAULT_CONFIG_PATH = "/etc/mywebapp/config.toml"


def _require(table: dict[str, Any], key: str, section: str) -> Any:
    if key not in table:
        raise ConfigError(f"missing required key [{section}].{key}")
    return table[key]


def _require_env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise ConfigError(f"missing required env var: {name}")
    return value


def _settings_from_env() -> Settings:
    try:
        server = ServerConfig(
            host=os.environ.get("MYWEBAPP_HOST", "0.0.0.0"),
            port=int(os.environ.get("MYWEBAPP_PORT", "8080")),
        )
        db = DbConfig(
            host=_require_env("MYWEBAPP_DB_HOST"),
            port=int(os.environ.get("MYWEBAPP_DB_PORT", "5432")),
            name=os.environ.get("MYWEBAPP_DB_NAME", "mywebapp"),
            user=os.environ.get("MYWEBAPP_DB_USER", "mywebapp"),
            password=_require_env("MYWEBAPP_DB_PASSWORD"),
            pool_min=int(os.environ.get("MYWEBAPP_DB_POOL_MIN", "2")),
            pool_max=int(os.environ.get("MYWEBAPP_DB_POOL_MAX", "10")),
        )
        log = LogConfig(level=os.environ.get("MYWEBAPP_LOG_LEVEL", "INFO"))
    except (TypeError, ValueError) as exc:
        raise ConfigError(f"invalid config value from env: {exc}") from exc
    return Settings(server=server, db=db, log=log)


def load_settings(path: str | os.PathLike[str] | None = None) -> Settings:
    if path is None and os.environ.get("MYWEBAPP_DB_HOST"):
        return _settings_from_env()

    resolved = Path(path or os.environ.get("MYWEBAPP_CONFIG") or DEFAULT_CONFIG_PATH)
    if not resolved.is_file():
        raise ConfigError(f"config file not found: {resolved}")

    try:
        raw = tomllib.loads(resolved.read_text(encoding="utf-8"))
    except tomllib.TOMLDecodeError as exc:
        raise ConfigError(f"invalid TOML in {resolved}: {exc}") from exc

    server_tbl = _expect_section(raw, "server")
    db_tbl = _expect_section(raw, "db")
    log_tbl_raw = raw.get("log")
    log_tbl: dict[str, Any] = log_tbl_raw if isinstance(log_tbl_raw, dict) else {}

    try:
        server = ServerConfig(
            host=str(_require(server_tbl, "host", "server")),
            port=int(_require(server_tbl, "port", "server")),
        )
        db = DbConfig(
            host=str(_require(db_tbl, "host", "db")),
            port=int(_require(db_tbl, "port", "db")),
            name=str(_require(db_tbl, "name", "db")),
            user=str(_require(db_tbl, "user", "db")),
            password=str(_require(db_tbl, "password", "db")),
            pool_min=int(db_tbl.get("pool_min", 2)),
            pool_max=int(db_tbl.get("pool_max", 10)),
        )
        log = LogConfig(level=str(log_tbl.get("level", "INFO")))
    except (TypeError, ValueError) as exc:
        raise ConfigError(f"invalid config value: {exc}") from exc

    return Settings(server=server, db=db, log=log)


def _expect_section(raw: dict[str, Any], name: str) -> dict[str, Any]:
    section = raw.get(name)
    if not isinstance(section, dict):
        raise ConfigError(f"missing or invalid [{name}] section")
    return section
