# mywebapp — Simple Inventory Service

**Лабораторна робота №1 — Розгортання Web-сервісу з автоматизацією.**
Автор: Бігіч Назар, група IM-XX, варіант **N = 5**.

## Варіант (обчислення)

```
V2 = (5 % 2) + 1 = 2  →  конфігурація: файл /etc/mywebapp/config.toml  +  БД PostgreSQL
V3 = (5 % 3) + 1 = 3  →  застосунок: Simple Inventory  (id, name, quantity, created_at)
V5 = (5 % 5) + 1 = 1  →  порт застосунку: 8080
```

## Призначення

Сервіс обліку обладнання (Simple Inventory). API:

| Метод | Шлях | Опис |
| --- | --- | --- |
| `GET` | `/` | HTML-список ендпоінтів бізнес-логіки |
| `GET` | `/items` | Перелік предметів `(id, name)` |
| `POST` | `/items` | Створити предмет `(name, quantity)` |
| `GET` | `/items/<id>` | Повна інформація про предмет |
| `GET` | `/health/alive` | Liveness (200 OK) |
| `GET` | `/health/ready` | Readiness (200 / 500 з причиною) |

Бізнес-ендпоінти підтримують content negotiation: `Accept: text/html` → проста HTML-сторінка без JS/CSS, `Accept: application/json` → JSON.

## Архітектура розгортання

```
client → nginx (0.0.0.0:80) → mywebapp (127.0.0.1:8080, socket-activated) → PostgreSQL (127.0.0.1:5432)
```

Усі компоненти на одній віртуальній машині. БД доступна лише з ВМ.

## Швидкий старт (розробка локально)

```bash
python3.12 -m venv .venv
source .venv/bin/activate
pip install -e '.[dev]'

# PostgreSQL у Docker (див. docs/dev-setup.md)
docker run -d --name mywebapp-pg -e POSTGRES_PASSWORD=dev -p 5432:5432 postgres:16

MYWEBAPP_CONFIG=./deploy/config/config.dev.toml \
    bash scripts/migrate.sh

MYWEBAPP_CONFIG=./deploy/config/config.dev.toml \
    bash scripts/dev_run.sh

# smoke
bash scripts/smoke.sh --dev
```

## Перевірки якості коду

```bash
ruff check .
mypy --strict app/
shellcheck deploy/install.sh deploy/lib/*.sh scripts/*.sh
pytest -q
```

## Розгортання на ВМ

Див. [`docs/install-runbook.md`](docs/install-runbook.md). Коротко:

```bash
sudo bash deploy/install.sh
```

## Документація

- [`docs/api.md`](docs/api.md) — повний опис ендпоінтів
- [`docs/install-runbook.md`](docs/install-runbook.md) — розгортання на ВМ
- [`docs/dev-setup.md`](docs/dev-setup.md) — локальне середовище розробки
