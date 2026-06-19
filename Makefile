.PHONY: up down restart logs ps topics topics-host lag lag-host lag-report snapshot smoke smoke-host test test-optional shellcheck

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
	docker compose exec kafka /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server kafka:29092 --describe --group orders-worker

lag-host:
	./scripts/kafka-lag.sh --bootstrap localhost:9092 --group orders-worker --topic orders

lag-report:
	./scripts/kafka-lag-report.sh --bootstrap localhost:9092 --group orders-worker --topic orders --out samples/reports/lag-report.local.md

snapshot:
	./scripts/kafka-lag-snapshot.sh --bootstrap localhost:9092 --group orders-worker --topic orders --out samples/reports/lag-snapshot.local.csv

smoke:
	docker compose exec kafka bash -lc 'MESSAGE_ID="kafka-toolkit-smoke-$$(date +%s)-$$RANDOM"; echo "$$MESSAGE_ID" | /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server kafka:29092 --topic healthcheck.kafka >/dev/null; /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server kafka:29092 --topic healthcheck.kafka --from-beginning --max-messages 100 --timeout-ms 10000 2>/dev/null | grep -F "$$MESSAGE_ID" >/dev/null && echo "OK: message roundtrip successful"'

smoke-host:
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
