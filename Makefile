# Gateway - persistent agent workbench
# Mirrors the target layout from TT IT's Docker Compose hosting model.

COMPOSE       := docker compose
COMPOSE_LOCAL := docker compose -f docker-compose.local.yml
SESSION       := $(shell . ./.env 2>/dev/null; echo $${GATEWAY_SESSION:-gateway})

.DEFAULT_GOAL := help
.PHONY: help setup build up down logs status restart attach shell clean \
        local-up local-down local-logs local-build local-attach ts-status doctor

help:
	@echo "TT Gateway - persistent agent workbench"
	@echo ""
	@echo "Production (on the IT-hosted VM):"
	@echo "  setup       - Copy env.example to .env"
	@echo "  build       - Build the workbench image"
	@echo "  up          - Start tailscale node + workbench"
	@echo "  down        - Stop all services"
	@echo "  restart     - Restart all services"
	@echo "  logs        - Follow logs from all services"
	@echo "  status      - Show service status"
	@echo ""
	@echo "Working with agents:"
	@echo "  attach      - Attach to the long-running tmux session"
	@echo "  shell       - Open a plain shell in the workbench"
	@echo "  ts-status   - Show tailnet peers visible to the agents"
	@echo "  doctor      - Verify the toolchain inside the image"
	@echo ""
	@echo "Local development (no tailnet node):"
	@echo "  local-build - Build for local use"
	@echo "  local-up    - Start just the workbench"
	@echo "  local-down  - Stop local services"
	@echo "  local-logs  - Follow local logs"
	@echo "  local-attach- Attach to the local tmux session"
	@echo ""
	@echo "  clean       - Remove containers and networks (keeps $$DATA_DIR)"

setup:
	@if [ -f .env ]; then echo ".env already exists; not overwriting."; else \
		cp env.example .env; \
		echo "Created .env - set TS_AUTHKEY before running make up."; \
	fi

build:
	$(COMPOSE) build

up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

restart:
	$(COMPOSE) restart

logs:
	$(COMPOSE) logs -f

status:
	$(COMPOSE) ps

# -it so the session is usable; detach with the tmux prefix then d.
attach:
	$(COMPOSE) exec -it workbench tmux -f /etc/gateway/tmux.conf attach -t $(SESSION)

shell:
	$(COMPOSE) exec -it workbench bash -l

ts-status:
	$(COMPOSE) exec tailscale tailscale status

doctor:
	$(COMPOSE) exec workbench doctor.sh

local-build:
	$(COMPOSE_LOCAL) build

local-up:
	$(COMPOSE_LOCAL) up -d

local-down:
	$(COMPOSE_LOCAL) down

local-logs:
	$(COMPOSE_LOCAL) logs -f

local-attach:
	$(COMPOSE_LOCAL) exec -it workbench tmux -f /etc/gateway/tmux.conf attach -t $(SESSION)

clean:
	$(COMPOSE) down --remove-orphans
	$(COMPOSE_LOCAL) down --remove-orphans
