.PHONY: up down restart logs ps topics lag lag-report snapshot smoke test test-optional shellcheck

up:
	docker compose up -d --build

down:
	docker compose down -v

restart:
	docker compose down -v
	docker compose up -d --build

logs:
	docker compose logs -f

ps:
	docker compose ps

topics:
	./samples/topics-docker.sh

topics-host:
	./samples/topics.sh --bootstrap localhost:9092

lag:
	./scripts/kafka-lag.sh --bootstrap localhost:9092 --group orders-worker --topic orders

lag-report:
	./scripts/kafka-lag-report.sh --bootstrap localhost:9092 --group orders-worker --topic orders --out samples/reports/lag-report.local.md

snapshot:
	./scripts/kafka-lag-snapshot.sh --bootstrap localhost:9092 --group orders-worker --topic orders --out samples/reports/lag-snapshot.local.csv

smoke:
	./scripts/kafka-smoke-test.sh --bootstrap localhost:9092 --topic healthcheck.kafka

test:
	@if ! command -v bats >/dev/null 2>&1; then \
		echo "bats is required for make test. Install bats or run make test-optional."; \
		exit 2; \
	fi
	bats tests

test-optional:
	@if command -v bats >/dev/null 2>&1; then \
		bats tests; \
	else \
		echo "Skipping tests: bats is not installed."; \
	fi

shellcheck:
	shellcheck scripts/*.sh lib/*.sh samples/topics.sh
