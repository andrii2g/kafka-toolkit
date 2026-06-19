#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/kafka-common.sh"
source "$ROOT_DIR/lib/markdown-table.sh"

BOOTSTRAP="$(kt_default_bootstrap)"
COMMAND_CONFIG="${KAFKA_COMMAND_CONFIG:-}"
TOPIC=""
COUNT=1000
TIMEOUT=30
FROM_BEGINNING=0
FORMAT="table"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bootstrap) BOOTSTRAP="${2:-}"; shift 2 ;;
    --topic) TOPIC="${2:-}"; shift 2 ;;
    --count) COUNT="${2:-}"; shift 2 ;;
    --timeout) TIMEOUT="${2:-}"; shift 2 ;;
    --from-beginning) FROM_BEGINNING=1; shift ;;
    --format) FORMAT="${2:-}"; shift 2 ;;
    --command-config) COMMAND_CONFIG="${2:-}"; shift 2 ;;
    --help) echo "Usage: kafka-partition-distribution.sh --topic TOPIC [--count NUMBER] [--format table|csv|markdown]"; exit 0 ;;
    *) kt_die "unknown argument: $1" ;;
  esac
done

[[ -n "$TOPIC" ]] || kt_die "--topic is required"
kt_require_cmd timeout
KAFKA_CONSUMER="$(kt_kafka_cmd kafka-console-consumer.sh)"
kt_require_cmd "$KAFKA_CONSUMER"
config_args=()
while IFS= read -r arg; do config_args+=("$arg"); done < <(kt_add_command_config_args "$COMMAND_CONFIG")
consumer_args=(--bootstrap-server "$BOOTSTRAP" "${config_args[@]}" --topic "$TOPIC" --max-messages "$COUNT" --property print.partition=true --property print.offset=true --property print.key=true)
[[ "$FROM_BEGINNING" -eq 1 ]] && consumer_args+=(--from-beginning)

rows="$(timeout "$TIMEOUT" "$KAFKA_CONSUMER" "${consumer_args[@]}" 2>/dev/null |
  awk '
    match($0, /Partition:[[:space:]]*([0-9]+)/, m) { seen[m[1]]++; total++ }
    END { for (p in seen) printf "%s,%s,%.2f%%\n", p, seen[p], (seen[p] / total) * 100 }
  ' | sort -n)"

case "$FORMAT" in
  csv)
    echo "partition,messages,percent"
    echo "$rows"
    ;;
  markdown)
    md_table_header "Partition" "Messages" "Percent"
    while IFS=, read -r p m pct; do [[ -n "$p" ]] && md_table_row "$p" "$m" "$pct"; done <<<"$rows"
    ;;
  table)
    echo "Topic: $TOPIC"
    echo "Sample size target: $COUNT"
    echo
    printf "%-10s %-10s %-8s\n" "Partition" "Messages" "Percent"
    while IFS=, read -r p m pct; do [[ -n "$p" ]] && printf "%-10s %-10s %-8s\n" "$p" "$m" "$pct"; done <<<"$rows"
    ;;
  *) kt_die "--format must be table, csv, or markdown" ;;
esac
