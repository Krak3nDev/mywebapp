FROM python:3.12-slim-bookworm AS builder

RUN python -m venv /opt/venv
ENV PATH=/opt/venv/bin:$PATH

COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt


FROM python:3.12-slim-bookworm AS runtime

# hadolint ignore=DL3008
RUN apt-get update \
 && apt-get install --no-install-recommends -y postgresql-client curl bash \
 && rm -rf /var/lib/apt/lists/*

RUN groupadd --system --gid 1001 app \
 && useradd --system --uid 1001 --gid app --home-dir /opt/app --shell /usr/sbin/nologin app

COPY --from=builder /opt/venv /opt/venv
ENV PATH=/opt/venv/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /opt/app

COPY --chown=app:app app/ ./app/
COPY --chown=app:app migrations/ ./migrations/
COPY --chown=app:app scripts/migrate.sh ./scripts/migrate.sh
RUN chmod 0755 ./scripts/migrate.sh

USER app

EXPOSE 8080

ENTRYPOINT ["uvicorn", "--factory", "app.main:create_app", "--host", "0.0.0.0", "--port", "8080", "--proxy-headers", "--forwarded-allow-ips=*"]
