.PHONY: up down build shell setup test logs

# Docker Compose shortcuts
up:
	docker compose up -d

down:
	docker compose down

build:
	docker compose build

shell:
	docker compose run --rm app bash

# Initial setup: install deps, create DB, run migrations, seed
setup:
	docker compose run --rm app mix setup

# Run tests
test:
	docker compose run --rm -e MIX_ENV=test app mix test

# Database commands
db-create:
	docker compose run --rm app mix ecto.create

db-migrate:
	docker compose run --rm app mix ecto.migrate

db-seed:
	docker compose run --rm app run priv/repo/seeds.exs

db-reset:
	docker compose run --rm app mix ecto.reset

# Phoenix server (interactive)
server:
	docker compose run --rm --service-ports app mix phx.server

# View logs
logs:
	docker compose logs -f app

logs-db:
	docker compose logs -f db
