#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/kafka-common.sh"
source "$ROOT_DIR/lib/markdown-table.sh"

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
    --help) echo "Usage: kafka-topic-watermark.sh --topic TOPIC [--format table|csv|markdown]"; exit 0 ;;
    *) kt_die "unknown argument: $1" ;;
  esac
done

[[ -n "$TOPIC" ]] || kt_die "--topic is required"
config_args=()
while IFS= read -r arg; do config_args+=("$arg"); done < <(kt_add_command_config_args "$COMMAND_CONFIG")

if command -v "$(kt_kafka_cmd kafka-get-offsets.sh)" >/dev/null 2>&1; then
  GET_OFFSETS="$(kt_kafka_cmd kafka-get-offsets.sh)"
  earliest="$("$GET_OFFSETS" --bootstrap-server "$BOOTSTRAP" "${config_args[@]}" --topic "$TOPIC" --time earliest)"
  latest="$("$GET_OFFSETS" --bootstrap-server "$BOOTSTRAP" "${config_args[@]}" --topic "$TOPIC" --time latest)"
else
  RUN_CLASS="$(kt_kafka_cmd kafka-run-class.sh)"
  kt_require_cmd "$RUN_CLASS"
  earliest="$("$RUN_CLASS" kafka.tools.GetOffsetShell --broker-list "$BOOTSTRAP" --topic "$TOPIC" --time -2)"
  latest="$("$RUN_CLASS" kafka.tools.GetOffsetShell --broker-list "$BOOTSTRAP" --topic "$TOPIC" --time -1)"
fi

rows="$(awk -F: 'NR==FNR { e[$2]=$3; next } { print $2 "," e[$2] "," $3 "," ($3 - e[$2]) }' <(sort <<<"$earliest") <(sort <<<"$latest"))"

case "$FORMAT" in
  csv)
    echo "partition,earliest,latest,retained_messages_approx"
    echo "$rows"
    ;;
  markdown)
    md_table_header "Partition" "Earliest" "Latest" "Retained Messages Approx"
    while IFS=, read -r p e l r; do [[ -n "$p" ]] && md_table_row "$p" "$e" "$l" "$r"; done <<<"$rows"
    ;;
  table)
    echo "Topic: $TOPIC"
    echo
    printf "%-10s %-12s %-12s %-12s\n" "Partition" "Earliest" "Latest" "Retained"
    while IFS=, read -r p e l r; do [[ -n "$p" ]] && printf "%-10s %-12s %-12s %-12s\n" "$p" "$e" "$l" "$r"; done <<<"$rows"
    echo
    awk -F, '{ total += $4 } END { print "Total approximate retained messages: " total + 0 }' <<<"$rows"
    ;;
  *) kt_die "--format must be table, csv, or markdown" ;;
esac
