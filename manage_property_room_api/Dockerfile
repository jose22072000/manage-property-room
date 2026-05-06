# ─── builder ──────────────────────────────────────────────────────────
FROM golang:1.23-bookworm AS builder

WORKDIR /src
ENV CGO_ENABLED=1

# go-sqlite3 needs gcc
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc libc6-dev \
 && rm -rf /var/lib/apt/lists/*

COPY go.mod go.sum* ./
RUN go mod download || true

COPY . .
RUN go build -trimpath -ldflags="-s -w" -o /out/api ./cmd/api

# ─── runtime ──────────────────────────────────────────────────────────
FROM debian:bookworm-slim AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates sqlite3 \
 && rm -rf /var/lib/apt/lists/* \
 && useradd -u 10001 -m app

WORKDIR /app
COPY --from=builder /out/api /app/api

ENV PORT=8080 \
    DB_DRIVER=sqlite \
    DB_DSN=/data/app.db

RUN mkdir -p /data && chown -R app:app /data /app
USER app

EXPOSE 8080
VOLUME ["/data"]
ENTRYPOINT ["/app/api"]
