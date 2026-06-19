#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/kafka-common.sh"
source "$ROOT_DIR/lib/markdown-table.sh"

BOOTSTRAP="$(kt_default_bootstrap)"
COMMAND_CONFIG="${KAFKA_COMMAND_CONFIG:-}"
GROUP=""
FORMAT="table"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bootstrap) BOOTSTRAP="${2:-}"; shift 2 ;;
    --group) GROUP="${2:-}"; shift 2 ;;
    --format) FORMAT="${2:-}"; shift 2 ;;
    --command-config) COMMAND_CONFIG="${2:-}"; shift 2 ;;
    --help) echo "Usage: kafka-group-matrix.sh --group GROUP [--format table|csv|markdown]"; exit 0 ;;
    *) kt_die "unknown argument: $1" ;;
  esac
done

[[ -n "$GROUP" ]] || kt_die "--group is required"
args=(--bootstrap "$BOOTSTRAP" --group "$GROUP" --format csv)
[[ -n "$COMMAND_CONFIG" ]] && args+=(--command-config "$COMMAND_CONFIG")
csv="$("$SCRIPT_DIR/kafka-lag.sh" "${args[@]}")"

summary="$(awk -F, 'NR > 1 { parts[$2]++; lag[$2] += ($6 == "" ? 0 : $6) } END { for (t in parts) print t "," parts[t] "," lag[t] }' <<<"$csv" | sort)"

case "$FORMAT" in
  csv)
    echo "topic,partitions,total_lag"
    echo "$summary"
    ;;
  markdown)
    md_table_header "Topic" "Partitions" "Total Lag"
    while IFS=, read -r topic partitions lag; do [[ -n "$topic" ]] && md_table_row "$topic" "$partitions" "$lag"; done <<<"$summary"
    ;;
  table)
    echo "Consumer group: $GROUP"
    echo
    printf "%-24s %-12s %-10s\n" "Topic" "Partitions" "Total Lag"
    while IFS=, read -r topic partitions lag; do [[ -n "$topic" ]] && printf "%-24s %-12s %-10s\n" "$topic" "$partitions" "$lag"; done <<<"$summary"
    ;;
  *) kt_die "--format must be table, csv, or markdown" ;;
esac
