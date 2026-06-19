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
    --help) echo "Usage: kafka-offset-backup.sh --group GROUP --out FILE [--topic TOPIC]"; exit 0 ;;
    *) kt_die "unknown argument: $1" ;;
  esac
done

[[ -n "$GROUP" ]] || kt_die "--group is required"
[[ -n "$OUT" ]] || kt_die "--out is required"
kt_require_cmd jq
args=(--bootstrap "$BOOTSTRAP" --group "$GROUP" --format csv)
[[ -n "$TOPIC" ]] && args+=(--topic "$TOPIC")
[[ -n "$COMMAND_CONFIG" ]] && args+=(--command-config "$COMMAND_CONFIG")
csv="$("$SCRIPT_DIR/kafka-lag.sh" "${args[@]}")"

awk -F, 'NR > 1 { print }' <<<"$csv" |
  jq -R -s --arg generatedUtc "$(kt_timestamp_utc)" --arg group "$GROUP" --arg topicFilter "$TOPIC" '
    {
      generatedUtc: $generatedUtc,
      group: $group,
      topicFilter: (if $topicFilter == "" then null else $topicFilter end),
      offsets: (
        split("\n")[:-1]
        | map(split(","))
        | map({
          topic: .[1],
          partition: (.[2] | tonumber),
          currentOffset: (if .[3] == "" then null else (.[3] | tonumber) end),
          logEndOffset: (if .[4] == "" then null else (.[4] | tonumber) end),
          lag: (if .[5] == "" then null else (.[5] | tonumber) end)
        })
      )
    }' | kt_write_output "$OUT"
