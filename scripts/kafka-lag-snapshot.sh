#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/kafka-common.sh"

BOOTSTRAP="$(kt_default_bootstrap)"
COMMAND_CONFIG="${KAFKA_COMMAND_CONFIG:-}"
GROUP=""
TOPIC=""
OUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bootstrap) BOOTSTRAP="${2:-}"; shift 2 ;;
    --group) GROUP="${2:-}"; shift 2 ;;
    --topic) TOPIC="${2:-}"; shift 2 ;;
    --out) OUT="${2:-}"; shift 2 ;;
    --command-config) COMMAND_CONFIG="${2:-}"; shift 2 ;;
    --help) echo "Usage: kafka-lag-snapshot.sh --group GROUP --out FILE [--topic TOPIC]"; exit 0 ;;
    *) kt_die "unknown argument: $1" ;;
  esac
done

[[ -n "$GROUP" ]] || kt_die "--group is required"
[[ -n "$OUT" ]] || kt_die "--out is required"
args=(--bootstrap "$BOOTSTRAP" --group "$GROUP" --format csv)
[[ -n "$TOPIC" ]] && args+=(--topic "$TOPIC")
[[ -n "$COMMAND_CONFIG" ]] && args+=(--command-config "$COMMAND_CONFIG")
csv="$("$SCRIPT_DIR/kafka-lag.sh" "${args[@]}")"
timestamp="$(kt_timestamp_utc)"

if [[ "$OUT" == "-" ]]; then
  echo "timestamp_utc,group,topic,partition,current_offset,log_end_offset,lag"
  awk -F, -v ts="$timestamp" 'NR > 1 { print ts "," $0 }' <<<"$csv"
else
  mkdir -p "$(dirname "$OUT")"
  if [[ ! -f "$OUT" ]]; then
    echo "timestamp_utc,group,topic,partition,current_offset,log_end_offset,lag" >"$OUT"
  fi
  awk -F, -v ts="$timestamp" 'NR > 1 { print ts "," $0 }' <<<"$csv" >>"$OUT"
fi
