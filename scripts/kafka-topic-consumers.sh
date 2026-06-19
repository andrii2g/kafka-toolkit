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
    --help) echo "Usage: kafka-topic-consumers.sh --topic TOPIC [--format table|csv|markdown]"; exit 0 ;;
    *) kt_die "unknown argument: $1" ;;
  esac
done

[[ -n "$TOPIC" ]] || kt_die "--topic is required"
KAFKA_CONSUMER_GROUPS="$(kt_kafka_cmd kafka-consumer-groups.sh)"
kt_require_cmd "$KAFKA_CONSUMER_GROUPS"
config_args=()
while IFS= read -r arg; do config_args+=("$arg"); done < <(kt_add_command_config_args "$COMMAND_CONFIG")
groups="$("$KAFKA_CONSUMER_GROUPS" --bootstrap-server "$BOOTSTRAP" "${config_args[@]}" --list)"

rows=""
while IFS= read -r group; do
  [[ -z "$group" ]] && continue
  lag_args=(--bootstrap "$BOOTSTRAP" --group "$group" --topic "$TOPIC" --format csv)
  [[ -n "$COMMAND_CONFIG" ]] && lag_args+=(--command-config "$COMMAND_CONFIG")
  csv="$("$SCRIPT_DIR/kafka-lag.sh" "${lag_args[@]}" 2>/dev/null || true)"
  total="$(awk -F, 'NR > 1 { seen=1; lag += ($6 == "" ? 0 : $6) } END { if (seen) print lag + 0 }' <<<"$csv")"
  [[ -n "$total" ]] && rows+="$group,$TOPIC,$total"$'\n'
done <<<"$groups"

case "$FORMAT" in
  csv)
    echo "group,topic,total_lag"
    printf '%s' "$rows"
    ;;
  markdown)
    md_table_header "Group" "Topic" "Total Lag"
    while IFS=, read -r g t l; do [[ -n "$g" ]] && md_table_row "$g" "$t" "$l"; done <<<"$rows"
    ;;
  table)
    echo "Topic: $TOPIC"
    echo
    printf "%-30s %-24s %-10s\n" "Group" "Topic" "Total Lag"
    while IFS=, read -r g t l; do [[ -n "$g" ]] && printf "%-30s %-24s %-10s\n" "$g" "$t" "$l"; done <<<"$rows"
    ;;
  *) kt_die "--format must be table, csv, or markdown" ;;
esac
