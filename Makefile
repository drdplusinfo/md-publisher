.PHONY: init run stop build test

MAKEFLAGS += --no-print-directory

# Hugo runs as this uid/gid in the container, so what it generates into the
# bind mount (public/, resources/, .hugo_build.lock) stays owned by you rather
# than root. A bare `docker compose` gets the same from .env — see .env.dist.
HOST_UID ?= $(shell id -u)
HOST_GID ?= $(shell id -g)
export HOST_UID
export HOST_GID

# The uid/gid are appended only while creating .env, never to an existing one:
# .env is the developer's file. Copying .env.dist alone would leave them
# commented out, and a bare `docker compose` would fall back to 1000:1000 —
# wrong ownership again on any host whose user is not uid 1000.
init:
	which docker > /dev/null || (echo "Please install docker binary" && exit 1)
	@[ -e .env ] || { cp .env.dist .env && printf 'HOST_UID=%s\nHOST_GID=%s\n' "$(HOST_UID)" "$(HOST_GID)" >> .env; }

run: init
	docker compose up -d
	@PORT=$$(docker compose port hugo 1313 2>/dev/null | cut -d: -f2); \
	echo "Blog demo (blog-classic) runs on http://localhost:$${PORT}"
	@PORT=$$(docker compose port hugo-rules 1313 2>/dev/null | cut -d: -f2); \
	echo "Book demo (rules-classic) runs on http://localhost:$${PORT}"

stop:
	docker compose down

build: init
	docker compose run --rm hugo --minify

test:
	./tests/run.sh
