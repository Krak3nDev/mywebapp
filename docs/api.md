# API mywebapp

Усі бізнес-ендпоінти підтримують **content negotiation** через заголовок `Accept`:
- `Accept: application/json` (або відсутній / `*/*`) → JSON
- `Accept: text/html` → проста HTML-сторінка, без JS і без CSS, списки у `<table>`

Кореневий ендпоінт `/` віддає **тільки** HTML.

| Метод | Шлях | Опис | Зовнішньо (через nginx)? |
| --- | --- | --- | --- |
| `GET` | `/` | HTML-список бізнес-ендпоінтів | так |
| `GET` | `/items` | Перелік предметів `(id, name)` | так |
| `POST` | `/items` | Створити предмет | так |
| `GET` | `/items/<id>` | Повна інформація про предмет | так |
| `GET` | `/health/alive` | Liveness (`200 OK`) | **ні** (404 із зовні) |
| `GET` | `/health/ready` | Readiness (200 / 500) | **ні** (404 із зовні) |

---

## `GET /`

HTML-сторінка зі списком бізнес-ендпоінтів.

```bash
curl -H 'Accept: text/html' http://localhost/
```

```html
<table>
  <tr><th>Method</th><th>Path</th></tr>
  <tr><td>GET</td><td><a href="/items">/items</a></td></tr>
  <tr><td>POST</td><td><a href="/items">/items</a></td></tr>
  <tr><td>GET</td><td><a href="/items/1">/items/&lt;id&gt;</a></td></tr>
</table>
```

---

## `GET /items`

### JSON
```bash
curl -H 'Accept: application/json' http://localhost/items
```
```json
[{"id":1,"name":"bolt"},{"id":2,"name":"nut"}]
```

### HTML
```bash
curl -H 'Accept: text/html' http://localhost/items
```
Таблиця з колонками `id`, `name` (name — посилання на `/items/<id>`).

---

## `POST /items`

Створює новий предмет. Тіло — JSON: `{"name": str, "quantity": int >= 0}`.

```bash
curl -X POST -H 'Content-Type: application/json' -H 'Accept: application/json' \
     -d '{"name":"bolt","quantity":42}' \
     http://localhost/items
```

Успіх: `201 Created`, заголовок `Location: /items/<id>`, тіло:
```json
{"id":1,"name":"bolt","quantity":42,"created_at":"2026-05-16T18:00:00+00:00"}
```

Помилки:
- `422` — невалідний JSON, пусте `name`, від'ємне `quantity`.

---

## `GET /items/<id>`

### JSON
```bash
curl -H 'Accept: application/json' http://localhost/items/1
```
```json
{"id":1,"name":"bolt","quantity":42,"created_at":"2026-05-16T18:00:00+00:00"}
```

### HTML
Таблиця "поле / значення" з усіма чотирма полями.

### Помилки
- `404 not found` — id відсутній.

---

## `GET /health/alive`

`200 OK` із тілом `OK`. Завжди.

## `GET /health/ready`

- `200 OK` (`OK`) — застосунок зміг виконати `SELECT 1` на БД.
- `500 Internal Server Error` (`db unavailable: <ExceptionClassName>`) — БД недоступна.

Externally (через nginx) обидва health-ендпоінти повертають `404` за рахунок директиви `location ^~ /health { return 404; }`.
