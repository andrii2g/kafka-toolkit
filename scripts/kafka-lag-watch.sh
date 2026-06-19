#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/kafka-common.sh"

BOOTSTRAP="$(kt_default_bootstrap)"
COMMAND_CONFIG="${KAFKA_COMMAND_CONFIG:-}"
GROUP=""
TOPIC=""
INTERVAL=5

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bootstrap) BOOTSTRAP="${2:-}"; shift 2 ;;
    --group) GROUP="${2:-}"; shift 2 ;;
    --topic) TOPIC="${2:-}"; shift 2 ;;
    --interval) INTERVAL="${2:-}"; shift 2 ;;
    --command-config) COMMAND_CONFIG="${2:-}"; shift 2 ;;
    --help) echo "Usage: kafka-lag-watch.sh --group GROUP [--topic TOPIC] [--interval SECONDS]"; exit 0 ;;
    *) kt_die "unknown argument: $1" ;;
  esac
done

[[ -n "$GROUP" ]] || kt_die "--group is required"
kt_is_number "$INTERVAL" || kt_die "--interval must be a number"

args=(--bootstrap "$BOOTSTRAP" --group "$GROUP")
[[ -n "$TOPIC" ]] && args+=(--topic "$TOPIC")
[[ -n "$COMMAND_CONFIG" ]] && args+=(--command-config "$COMMAND_CONFIG")

while true; do
  clear || true
  date -u +"%Y-%m-%dT%H:%M:%SZ"
  "$SCRIPT_DIR/kafka-lag.sh" "${args[@]}"
  sleep "$INTERVAL"
done
