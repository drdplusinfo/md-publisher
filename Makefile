.PHONY: run stop build

MAKEFLAGS += --no-print-directory

run:
	docker compose up -d
	@PORT=$$(docker compose port hugo 1313 2>/dev/null | cut -d: -f2); \
	echo "Site runs on http://localhost:$${PORT}"

stop:
	docker compose down

build:
	docker compose run --rm hugo --minify
