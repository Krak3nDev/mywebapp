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

## Запуск через Docker Compose (Лабораторна №2)

```bash
cp .env.example .env
# відредагуйте POSTGRES_PASSWORD / MYWEBAPP_DB_PASSWORD у .env
docker compose up -d --build
```

Сервіси: `nginx` (публічний :80) → `app` (FastAPI :8080) → `postgres:16-alpine` (named volume `mywebapp-pgdata`). Окрема мережа `mywebapp-net`. Міграції виконуються одноразовим сервісом `migrate` перед стартом `app`.

Перевірка:
```bash
curl http://localhost/items
curl -X POST -H 'Content-Type: application/json' -d '{"name":"bolt","quantity":3}' http://localhost/items
docker compose ps                        # migrate Exited(0); app/nginx/postgres healthy
```

Збереження даних:
- `docker compose down` — контейнери видалено, том `mywebapp-pgdata` залишається; `up -d` повертає попередні дані.
- `docker compose down -v` — деструктивно, том знищено, наступний `up -d` створить порожню БД.

Troubleshooting:
- Конфлікт хост-порту 80 → виставити `MYWEBAPP_HOST_PORT=8080` у `.env`.
- Сервіс `app` не стартує (`unhealthy` / залежності) → `docker compose logs migrate` (можлива помилка SQL/credentials).
- Очистити все одразу: `docker compose down --volumes --remove-orphans`.

## Розгортання на ВМ (systemd, без Docker)

Див. [`docs/install-runbook.md`](docs/install-runbook.md). Коротко:

```bash
sudo bash deploy/install.sh
```

## CI/CD (Лабораторна №3)

Один workflow `.github/workflows/ci.yml`, 5 jobs:

| Тригер | lint | test | build | deploy | verify |
| --- | --- | --- | --- | --- | --- |
| push до `main` | ✓ | ✓ + coverage artifact | ✓ (`latest`, `sha-<full>`) | — | — |
| PR до `main` | ✓ | ✓ (блокує merge при fail) | — | — | — |
| анотований тег `v*` | ✓ | ✓ | ✓ (`stable`, `<tag>`) | ✓ (на self-hosted runner) | ✓ |

GHCR публікація: `ghcr.io/krak3ndev/mywebapp:<tag>`. Self-hosted runner на окремій ВМ (mark `lab3-runner`), SSH-доступ до target-node з ключа в `secrets.TARGET_SSH_KEY`.

Покриття коду тестами: ≥40% (gate; зараз ~86%). Артефакти: `coverage-html`, `coverage.xml` на pushes до `main` і тегах.

Документація розгортання Lab 3 (VM provisioning, реєстрація runner'а, branch protection, демо-теги): [`docs/runbook.md`](docs/runbook.md). План демонстрацій: [`docs/demo-plan.md`](docs/demo-plan.md).

## Документація

- [`docs/api.md`](docs/api.md) — повний опис ендпоінтів
- [`docs/install-runbook.md`](docs/install-runbook.md) — розгортання на ВМ (Лаба №1, systemd)
- [`docs/dev-setup.md`](docs/dev-setup.md) — локальне середовище розробки
- [`docs/runbook.md`](docs/runbook.md) — CI/CD runbook (Лаба №3)
- [`docs/demo-plan.md`](docs/demo-plan.md) — план демонстрацій для звіту
