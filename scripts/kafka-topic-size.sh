#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/kafka-common.sh"

BOOTSTRAP="$(kt_default_bootstrap)"
COMMAND_CONFIG="${KAFKA_COMMAND_CONFIG:-}"
TOPIC=""
FORMAT="table"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bootstrap) BOOTSTRAP="${2:-}"; shift 2 ;;
    --topic) TOPIC="${2:-}"; shift 2 ;;
    --format) FORMAT="${2:-}"; shift 2 ;;
    --command-config) COMMAND_CONFIG="${2:-}"; shift 2 ;;
    --help) echo "Usage: kafka-topic-size.sh --topic TOPIC [--format table|csv|json]"; exit 0 ;;
    *) kt_die "unknown argument: $1" ;;
  esac
done

[[ -n "$TOPIC" ]] || kt_die "--topic is required"
args=(--bootstrap "$BOOTSTRAP" --topic "$TOPIC" --format csv)
[[ -n "$COMMAND_CONFIG" ]] && args+=(--command-config "$COMMAND_CONFIG")
csv="$("$SCRIPT_DIR/kafka-topic-watermark.sh" "${args[@]}")"
read -r partitions total < <(awk -F, 'NR > 1 { p++; total += $4 } END { print p + 0, total + 0 }' <<<"$csv")

case "$FORMAT" in
  csv)
    echo "topic,partitions,retained_messages_approx"
    echo "$TOPIC,$partitions,$total"
    ;;
  json)
    kt_require_cmd jq
    jq -n --arg topic "$TOPIC" --argjson partitions "$partitions" --argjson retained "$total" \
      '{topic:$topic,partitions:$partitions,retainedMessagesApprox:$retained}'
    ;;
  table)
    echo "Topic: $TOPIC"
    echo "Approximate retained messages: $total"
    echo "Partitions: $partitions"
    ;;
  *) kt_die "--format must be table, csv, or json" ;;
esac
