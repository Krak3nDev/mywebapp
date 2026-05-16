# Локальне dev-середовище

## Передумови

- Python 3.12
- Docker (для локального PostgreSQL)
- `shellcheck` (для перевірки bash-скриптів)

## Підняти PostgreSQL у docker

```bash
docker run -d --name mywebapp-pg \
  -e POSTGRES_USER=mywebapp \
  -e POSTGRES_PASSWORD=dev \
  -e POSTGRES_DB=mywebapp \
  -p 5432:5432 \
  postgres:16
```

Перевірити:
```bash
PGPASSWORD=dev psql -h 127.0.0.1 -U mywebapp -d mywebapp -c 'select 1'
```

## Venv + залежності

```bash
python3.12 -m venv .venv
source .venv/bin/activate
pip install -e '.[dev]'
```

## Конфіг

Готовий dev-конфіг лежить у `deploy/config/config.dev.toml` (паролем `dev`, як у docker-команді вище).

```bash
export MYWEBAPP_CONFIG=$PWD/deploy/config/config.dev.toml
```

## Міграції

```bash
bash scripts/migrate.sh
# повторно — нічого не змінює:
bash scripts/migrate.sh
```

## Запуск застосунку

```bash
bash scripts/dev_run.sh
# слухає http://127.0.0.1:8080
```

## Тести і lint

```bash
pytest -q
ruff check .
mypy --strict app/
shellcheck deploy/install.sh deploy/lib/*.sh scripts/*.sh
```

## Smoke тест (dev)

```bash
bash scripts/smoke.sh --dev
```

## Очистка

```bash
docker rm -f mywebapp-pg
rm -rf .venv .ruff_cache .mypy_cache .pytest_cache
```
