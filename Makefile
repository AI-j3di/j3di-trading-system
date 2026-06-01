# ══════════════════════════════════════════════════════════════════════════════
# J3DI Trading System — Docker GPU Development Commands (P16)
# Usage: make <target>
# ══════════════════════════════════════════════════════════════════════════════

.PHONY: build up down restart logs shell test jupyter mlflow gpu train clean nuke

# ── Build & Run ──────────────────────────────────────────────────────────────

build:			## Build all containers (GPU image — ~30 min first time)
	docker compose build

up:				## Start core services (dev + mlflow + postgres + redis)
	docker compose up -d

down:			## Stop all services
	docker compose down

restart:		## Restart all services
	docker compose restart

# ── Training Container (separate from Jupyter) ───────────────────────────────

train-up:		## Start training container alongside core services
	docker compose --profile training up -d

train-shell:	## Bash shell in training container
	docker exec -it j3di-train bash

train-run:		## Run a training script (edit path as needed)
	docker exec -it j3di-train python scripts/train.py

train-down:		## Stop training container only (core stays running)
	docker compose --profile training stop j3di-train

# ── Access ───────────────────────────────────────────────────────────────────

shell:			## Open bash in dev container
	docker exec -it j3di-dev bash

jupyter:		## Show JupyterLab URL
	@echo "→ http://localhost:8888/?token=j3di"

mlflow:			## Show MLflow URL
	@echo "→ http://localhost:5000"

psql:			## Connect to PostgreSQL
	docker exec -it j3di-postgres psql -U j3di -d j3di

# ── GPU Monitoring ───────────────────────────────────────────────────────────

gpu:			## Show GPU status (nvidia-smi inside container)
	docker exec -it j3di-dev nvidia-smi

gpu-watch:		## Live GPU monitoring (refreshes every 2s)
	docker exec -it j3di-dev watch -n 2 nvidia-smi

gpu-top:		## Interactive GPU process monitor
	docker exec -it j3di-dev nvtop

gpu-mem:		## Show GPU memory usage for running Python processes
	docker exec -it j3di-dev nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv

# ── Development ──────────────────────────────────────────────────────────────

test:			## Run pytest inside container
	docker exec -it j3di-dev pytest tests/ -v

lint:			## Run ruff + black check
	docker exec -it j3di-dev ruff check src/
	docker exec -it j3di-dev black --check src/

format:			## Auto-format code
	docker exec -it j3di-dev black src/ tests/
	docker exec -it j3di-dev isort src/ tests/

backtest:		## Run backtest script
	docker exec -it j3di-dev python scripts/run_backtest.py

verify:			## Run environment verification
	docker exec -it j3di-dev python scripts/verify_docker_setup.py

# ── Monitoring ───────────────────────────────────────────────────────────────

logs:			## Tail logs from all services
	docker compose logs -f --tail=50

logs-dev:		## Tail dev container logs only
	docker compose logs -f --tail=50 j3di-dev

logs-train:		## Tail training container logs only
	docker compose logs -f --tail=50 j3di-train

status:			## Show running containers and resource usage
	@docker compose ps
	@echo ""
	@docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" \
		j3di-dev j3di-train j3di-mlflow j3di-postgres j3di-redis 2>/dev/null || true
	@echo ""
	@echo "── GPU ──"
	@docker exec j3di-dev nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu --format=csv,noheader 2>/dev/null || echo "GPU not available"

# ── Cleanup ──────────────────────────────────────────────────────────────────

clean:			## Stop containers, remove images (keeps volumes)
	docker compose --profile training down --rmi local

nuke:			## ⚠️  Stop everything, remove volumes + images (DATA LOSS)
	@echo "⚠️  This will delete ALL data volumes (DB, models, logs)."
	@read -p "Type YES to confirm: " confirm; \
	if [ "$$confirm" = "YES" ]; then \
		docker compose --profile training down -v --rmi local; \
		echo "✅ All containers, images, and volumes removed."; \
	else \
		echo "❌ Cancelled."; \
	fi

# ── Help ─────────────────────────────────────────────────────────────────────

help:			## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
