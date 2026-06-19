#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/kafka-common.sh"
source "$ROOT_DIR/lib/markdown-table.sh"

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
    --help) echo "Usage: kafka-lag-report.sh --group GROUP --out FILE [--topic TOPIC] [--bootstrap HOSTS]"; exit 0 ;;
    *) kt_die "unknown argument: $1" ;;
  esac
done

[[ -n "$GROUP" ]] || kt_die "--group is required"
[[ -n "$OUT" ]] || kt_die "--out is required"

args=(--bootstrap "$BOOTSTRAP" --group "$GROUP" --format csv)
[[ -n "$TOPIC" ]] && args+=(--topic "$TOPIC")
[[ -n "$COMMAND_CONFIG" ]] && args+=(--command-config "$COMMAND_CONFIG")
csv="$("$SCRIPT_DIR/kafka-lag.sh" "${args[@]}")"

{
  echo "# Kafka Lag Report"
  echo
  echo "Generated UTC: \`$(kt_timestamp_utc)\`"
  echo
  echo "Consumer group: \`$GROUP\`"
  [[ -n "$TOPIC" ]] && echo "Topic: \`$TOPIC\`"
  echo
  md_table_header "Partition" "Current Offset" "End Offset" "Lag"
  awk -F, 'NR > 1 { print $3 "," $4 "," $5 "," $6 }' <<<"$csv" |
    while IFS=, read -r partition current end lag; do
      md_table_row "$partition" "$current" "$end" "$lag"
    done
  total="$(awk -F, 'NR > 1 { total += ($6 == "" ? 0 : $6) } END { print total + 0 }' <<<"$csv")"
  echo
  echo "Total lag: **$total**"
} | kt_write_output "$OUT"
