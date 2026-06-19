#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/kafka-common.sh"

BOOTSTRAP="$(kt_default_bootstrap)"
COMMAND_CONFIG="${KAFKA_COMMAND_CONFIG:-}"
GROUP=""
TOPIC=""
MAX_LAG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bootstrap) BOOTSTRAP="${2:-}"; shift 2 ;;
    --group) GROUP="${2:-}"; shift 2 ;;
    --topic) TOPIC="${2:-}"; shift 2 ;;
    --max-lag) MAX_LAG="${2:-}"; shift 2 ;;
    --command-config) COMMAND_CONFIG="${2:-}"; shift 2 ;;
    --help) echo "Usage: kafka-lag-check.sh --group GROUP --max-lag NUMBER [--topic TOPIC]"; exit 0 ;;
    *) kt_die "unknown argument: $1" ;;
  esac
done

[[ -n "$GROUP" ]] || kt_die "--group is required"
kt_is_number "$MAX_LAG" || kt_die "--max-lag must be a number"

args=(--bootstrap "$BOOTSTRAP" --group "$GROUP" --format csv)
[[ -n "$TOPIC" ]] && args+=(--topic "$TOPIC")
[[ -n "$COMMAND_CONFIG" ]] && args+=(--command-config "$COMMAND_CONFIG")
csv="$("$SCRIPT_DIR/kafka-lag.sh" "${args[@]}")"
total="$(awk -F, 'NR > 1 { total += ($6 == "" ? 0 : $6) } END { print total + 0 }' <<<"$csv")"

if (( total > MAX_LAG )); then
  echo "FAIL: total lag is $total, threshold is $MAX_LAG"
  exit 1
fi

echo "OK: total lag is $total, threshold is $MAX_LAG"
