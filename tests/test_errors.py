
from app.handlers import redact


def test_redact_strips_password_kv() -> None:
    msg = "connection failed: host=h password=supersecret user=mywebapp"
    out = redact(msg)
    assert "supersecret" not in out
    assert "password=***" in out


def test_redact_strips_dsn_credentials() -> None:
    msg = "could not connect: postgresql://mywebapp:hunter2@127.0.0.1:5432/mywebapp"
    out = redact(msg)
    assert "hunter2" not in out


def test_redact_is_idempotent() -> None:
    msg = "password=secret"
    assert redact(redact(msg)) == redact(msg)
