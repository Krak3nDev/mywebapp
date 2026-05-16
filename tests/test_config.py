
from pathlib import Path

import pytest

from app.config import ConfigError, load_settings

VALID_TOML = """
[server]
host = "127.0.0.1"
port = 8080

[db]
host = "127.0.0.1"
port = 5432
name = "mywebapp"
user = "mywebapp"
password = "secret"
pool_min = 2
pool_max = 10

[log]
level = "DEBUG"
"""


def _write(tmp_path: Path, content: str) -> Path:
    p = tmp_path / "config.toml"
    p.write_text(content)
    return p


def test_load_valid_config(tmp_path: Path) -> None:
    path = _write(tmp_path, VALID_TOML)
    settings = load_settings(path)
    assert settings.server.port == 8080
    assert settings.db.pool_max == 10
    assert settings.log.level == "DEBUG"


def test_missing_required_key_raises(tmp_path: Path) -> None:
    path = _write(tmp_path, "[server]\nhost='x'\n[db]\nhost='x'\n")
    with pytest.raises(ConfigError) as excinfo:
        load_settings(path)
    assert "missing required key" in str(excinfo.value)


def test_missing_file_raises(tmp_path: Path) -> None:
    with pytest.raises(ConfigError):
        load_settings(tmp_path / "does-not-exist.toml")


def test_env_var_override(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    path = _write(tmp_path, VALID_TOML)
    monkeypatch.setenv("MYWEBAPP_CONFIG", str(path))
    settings = load_settings()
    assert settings.server.port == 8080
