#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/kafka-common.sh"

BOOTSTRAP="$(kt_default_bootstrap)"
COMMAND_CONFIG="${KAFKA_COMMAND_CONFIG:-}"
GROUP=""
INTERVAL=2

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bootstrap) BOOTSTRAP="${2:-}"; shift 2 ;;
    --group) GROUP="${2:-}"; shift 2 ;;
    --interval) INTERVAL="${2:-}"; shift 2 ;;
    --command-config) COMMAND_CONFIG="${2:-}"; shift 2 ;;
    --help) echo "Usage: kafka-rebalance-watch.sh --group GROUP [--interval SECONDS]"; exit 0 ;;
    *) kt_die "unknown argument: $1" ;;
  esac
done

[[ -n "$GROUP" ]] || kt_die "--group is required"
kt_is_number "$INTERVAL" || kt_die "--interval must be a number"
last=""
args=(--bootstrap "$BOOTSTRAP" --group "$GROUP" --format csv)
[[ -n "$COMMAND_CONFIG" ]] && args+=(--command-config "$COMMAND_CONFIG")

while true; do
  line="$("$SCRIPT_DIR/kafka-group-state.sh" "${args[@]}" | awk -F, 'NR == 2 { print $2 "," $3 "," $4 }')"
  if [[ "$line" != "$last" ]]; then
    echo "$(kt_timestamp_utc),$GROUP,$line"
    last="$line"
  fi
  sleep "$INTERVAL"
done
