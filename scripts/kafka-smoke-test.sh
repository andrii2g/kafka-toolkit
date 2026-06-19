#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/kafka-common.sh"

BOOTSTRAP="$(kt_default_bootstrap)"
COMMAND_CONFIG="${KAFKA_COMMAND_CONFIG:-}"
TOPIC="healthcheck.kafka"
TIMEOUT=15

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bootstrap) BOOTSTRAP="${2:-}"; shift 2 ;;
    --topic) TOPIC="${2:-}"; shift 2 ;;
    --timeout) TIMEOUT="${2:-}"; shift 2 ;;
    --command-config) COMMAND_CONFIG="${2:-}"; shift 2 ;;
    --help) echo "Usage: kafka-smoke-test.sh [--topic TOPIC] [--timeout SECONDS]"; exit 0 ;;
    *) kt_die "unknown argument: $1" ;;
  esac
done

KAFKA_TOPICS="$(kt_kafka_cmd kafka-topics.sh)"
KAFKA_PRODUCER="$(kt_kafka_cmd kafka-console-producer.sh)"
KAFKA_CONSUMER="$(kt_kafka_cmd kafka-console-consumer.sh)"
kt_require_cmd "$KAFKA_TOPICS"
kt_require_cmd "$KAFKA_PRODUCER"
kt_require_cmd "$KAFKA_CONSUMER"
kt_require_cmd timeout
config_args=()
while IFS= read -r arg; do config_args+=("$arg"); done < <(kt_add_command_config_args "$COMMAND_CONFIG")

"$KAFKA_TOPICS" --bootstrap-server "$BOOTSTRAP" "${config_args[@]}" --create --if-not-exists --topic "$TOPIC" --partitions 1 --replication-factor 1 >/dev/null
message_id="kafka-toolkit-smoke-$(date +%s)-$RANDOM"
echo "Producing test message..."
printf '%s\n' "$message_id" | "$KAFKA_PRODUCER" --bootstrap-server "$BOOTSTRAP" "${config_args[@]}" --topic "$TOPIC" >/dev/null
echo "Consuming test message..."
if timeout "$TIMEOUT" "$KAFKA_CONSUMER" --bootstrap-server "$BOOTSTRAP" "${config_args[@]}" --topic "$TOPIC" --from-beginning --max-messages 100 2>/dev/null | grep -F "$message_id" >/dev/null; then
  echo "OK: message roundtrip successful"
  exit 0
fi
echo "FAIL: smoke message was not consumed before timeout"
exit 1
