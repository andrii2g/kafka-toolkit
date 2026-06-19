#!/usr/bin/env bash
set -euo pipefail

COMPOSE="${COMPOSE:-docker compose}"
KAFKA_SERVICE="${KAFKA_SERVICE:-kafka}"
BOOTSTRAP="${KAFKA_BOOTSTRAP_SERVERS:-kafka:29092}"
KAFKA_TOPICS="${KAFKA_TOPICS:-/opt/kafka/bin/kafka-topics.sh}"

create_topic() {
  local topic="$1"
  local partitions="$2"

  # shellcheck disable=SC2086
  $COMPOSE exec "$KAFKA_SERVICE" "$KAFKA_TOPICS" \
    --bootstrap-server "$BOOTSTRAP" \
    --create \
    --if-not-exists \
    --topic "$topic" \
    --partitions "$partitions" \
    --replication-factor 1
}

create_topic orders 6
create_topic payments 3
create_topic notifications 4
create_topic healthcheck.kafka 1
