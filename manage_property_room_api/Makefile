.PHONY: dev local build test seed clean docker-build docker-up docker-down

# Local dev (no docker): requires Go installed and CGO enabled (for sqlite3).
local:
	@test -f .env || cp .env.example .env
	CGO_ENABLED=1 go run ./cmd/api

build:
	CGO_ENABLED=1 go build -o bin/api ./cmd/api

test:
	CGO_ENABLED=1 go test ./...

# Seed runs as part of `local` / `dev` automatically (idempotent).
seed: local

# Dockerized dev environment.
dev: docker-up

docker-build:
	docker compose build

docker-up:
	@test -f .env || cp .env.example .env
	docker compose up --build

docker-down:
	docker compose down

clean:
	rm -rf bin/ data/
