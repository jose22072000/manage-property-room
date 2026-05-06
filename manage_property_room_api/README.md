# manage_property_room_api

REST API backend for the Property Room app.

**Stack:** Go 1.23 · chi · sqlx · SQLite (`mattn/go-sqlite3`) · golang-migrate · JWT (`jwt/v5`) · bcrypt.

## Quick start (Docker)

```bash
cp .env.example .env
make dev          # builds image, runs migrations + seed, listens on :8080
curl http://localhost:8080/health
# → {"ok":true}
```

The seed creates an admin user:

- Email: `maria@app.local`
- Password: `admin123`

Test login:

```bash
curl -X POST http://localhost:8080/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"maria@app.local","password":"admin123"}'
```

## Local (no Docker)

Requires Go 1.23+ and a C toolchain (gcc) for `mattn/go-sqlite3`.

```bash
cp .env.example .env
make local
```

The DB file lives at `./data/app.db` (created on first run).

## Project layout

```
cmd/api/                 # HTTP entrypoint
internal/
  config/                # env / .env loader
  domain/                # pure entities (mirrors Flutter lib/domain)
  store/                 # persistence interfaces
  store/sqlite/          # SQLite impl + embedded migrations
  auth/                  # bcrypt + JWT + login service
  httpx/                 # JSON helpers + auth middleware
  handlers/              # HTTP handlers (one file per resource group)
  router/                # chi router wiring
  seed/                  # demo data on first start
```

## Endpoints

See the full contract in the Flutter plan (`api_contract.md`). Highlights:

- `POST /auth/login` · `POST /auth/refresh` · `POST /auth/logout` · `POST /auth/change-password`
- `GET /me` · `GET/POST/PATCH/DELETE /users` · `POST /users/:id/reset-password`
- `GET/POST/PATCH/DELETE /properties` · `POST /properties/:id/assign-workers` · `GET /properties/:id/board`
- `POST /properties/:id/columns` · `PATCH/DELETE /columns/:id` · column actions: `duplicate`, `copy-to/:propertyId`, `move`, `move-cards-to/:targetId`, `archive-all-cards`, `archive`, `config`
- `POST /columns/:id/cards` · `GET/PATCH/DELETE /cards/:id` · `move`, `toggle-done`, `archive`, `assign`
- `GET/POST/PATCH/DELETE /fields` · `POST /fields/reorder`
- `GET/POST /cards/:id/comments` · `GET /cards/:id/activity`
- `GET /archive` · `POST /archive/:id/restore`
- `GET /health`

All endpoints (except `/health` and `/auth/login`) require `Authorization: Bearer <jwt>`.

Mutating endpoints under `/users`, `/fields`, `/properties` require `role=admin`.

Error envelope:

```json
{ "error": { "code": "INVALID_CREDENTIALS", "message": "..." } }
```

## Migrations

Embedded in the binary (`internal/store/sqlite/migrations/`). Applied automatically on startup.

To roll back manually you can use the [migrate CLI](https://github.com/golang-migrate/migrate):

```bash
migrate -path internal/store/sqlite/migrations -database "sqlite3://./data/app.db" down 1
```

## Switching DB engines later

`internal/store` defines driver-agnostic interfaces. To support Postgres:

1. Add `internal/store/postgres/` with a sister implementation.
2. Add `internal/store/postgres/migrations/` (separate dialect).
3. Read `DB_DRIVER` in `cmd/api/main.go` and dispatch.

Domain types and HTTP layer don't change.

## Tests

```bash
make test
```

(Tests use SQLite `:memory:` — no external dependencies.)

## Configuration

| Variable       | Default              | Notes |
|----------------|----------------------|-------|
| `PORT`         | `8080`               | HTTP port |
| `ENV`          | `dev`                | logging hint |
| `DB_DRIVER`    | `sqlite`             | only `sqlite` for now |
| `DB_DSN`       | `./data/app.db`      | file path or `:memory:` |
| `JWT_SECRET`   | *required*           | HS256 secret |
| `JWT_TTL`      | `24h`                | Go duration |
| `CORS_ORIGINS` | `*`                  | comma-separated; `*` for any (dev) |

## License

Internal — not for redistribution.
