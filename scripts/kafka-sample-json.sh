#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/kafka-common.sh"

BOOTSTRAP="$(kt_default_bootstrap)"
COMMAND_CONFIG="${KAFKA_COMMAND_CONFIG:-}"
TOPIC=""
COUNT=10
TIMEOUT=15
FROM_BEGINNING=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bootstrap) BOOTSTRAP="${2:-}"; shift 2 ;;
    --topic) TOPIC="${2:-}"; shift 2 ;;
    --count) COUNT="${2:-}"; shift 2 ;;
    --timeout) TIMEOUT="${2:-}"; shift 2 ;;
    --from-beginning) FROM_BEGINNING=1; shift ;;
    --command-config) COMMAND_CONFIG="${2:-}"; shift 2 ;;
    --help) echo "Usage: kafka-sample-json.sh --topic TOPIC [--count NUMBER] [--from-beginning]"; exit 0 ;;
    *) kt_die "unknown argument: $1" ;;
  esac
done

[[ -n "$TOPIC" ]] || kt_die "--topic is required"
kt_require_cmd jq
kt_require_cmd timeout
KAFKA_CONSUMER="$(kt_kafka_cmd kafka-console-consumer.sh)"
kt_require_cmd "$KAFKA_CONSUMER"
config_args=()
while IFS= read -r arg; do config_args+=("$arg"); done < <(kt_add_command_config_args "$COMMAND_CONFIG")
consumer_args=(--bootstrap-server "$BOOTSTRAP" "${config_args[@]}" --topic "$TOPIC" --max-messages "$COUNT")
[[ "$FROM_BEGINNING" -eq 1 ]] && consumer_args+=(--from-beginning)

timeout "$TIMEOUT" "$KAFKA_CONSUMER" "${consumer_args[@]}" 2>/dev/null |
  while IFS= read -r line; do
    if jq . >/dev/null 2>&1 <<<"$line"; then
      jq . <<<"$line"
    else
      echo "INVALID_JSON: $line"
    fi
  done
