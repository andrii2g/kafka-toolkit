#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/kafka-common.sh"
source "$ROOT_DIR/lib/markdown-table.sh"

BOOTSTRAP="$(kt_default_bootstrap)"
COMMAND_CONFIG="${KAFKA_COMMAND_CONFIG:-}"
TOPIC=""
MIN_LAG=1
FORMAT="table"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bootstrap) BOOTSTRAP="${2:-}"; shift 2 ;;
    --topic) TOPIC="${2:-}"; shift 2 ;;
    --min-lag) MIN_LAG="${2:-}"; shift 2 ;;
    --format) FORMAT="${2:-}"; shift 2 ;;
    --command-config) COMMAND_CONFIG="${2:-}"; shift 2 ;;
    --help) echo "Usage: kafka-dead-consumers.sh [--topic TOPIC] [--min-lag NUMBER]"; exit 0 ;;
    *) kt_die "unknown argument: $1" ;;
  esac
done

kt_is_number "$MIN_LAG" || kt_die "--min-lag must be a number"
KAFKA_CONSUMER_GROUPS="$(kt_kafka_cmd kafka-consumer-groups.sh)"
kt_require_cmd "$KAFKA_CONSUMER_GROUPS"
config_args=()
while IFS= read -r arg; do config_args+=("$arg"); done < <(kt_add_command_config_args "$COMMAND_CONFIG")
groups="$("$KAFKA_CONSUMER_GROUPS" --bootstrap-server "$BOOTSTRAP" "${config_args[@]}" --list)"

rows=""
while IFS= read -r group; do
  [[ -z "$group" ]] && continue
  state_args=(--bootstrap "$BOOTSTRAP" --group "$group" --format csv)
  [[ -n "$COMMAND_CONFIG" ]] && state_args+=(--command-config "$COMMAND_CONFIG")
  state_csv="$("$SCRIPT_DIR/kafka-group-state.sh" "${state_args[@]}" 2>/dev/null || true)"
  state="$(awk -F, 'NR == 2 { print $2 }' <<<"$state_csv")"
  members="$(awk -F, 'NR == 2 { print $3 }' <<<"$state_csv")"
  matrix_args=(--bootstrap "$BOOTSTRAP" --group "$group" --format csv)
  [[ -n "$COMMAND_CONFIG" ]] && matrix_args+=(--command-config "$COMMAND_CONFIG")
  matrix="$("$SCRIPT_DIR/kafka-group-matrix.sh" "${matrix_args[@]}" 2>/dev/null || true)"
  awk -F, -v group="$group" -v state="$state" -v members="${members:-0}" -v topic_filter="$TOPIC" -v min="$MIN_LAG" '
    NR > 1 && (topic_filter == "" || $1 == topic_filter) && $3 >= min && (members == 0 || state == "Empty" || state == "Dead") {
      print group "," $1 "," $3 "," members "," state
    }' <<<"$matrix" || true
done <<<"$groups" >"${TMPDIR:-/tmp}/kafka-dead-consumers.$$"
rows="$(cat "${TMPDIR:-/tmp}/kafka-dead-consumers.$$")"
rm -f "${TMPDIR:-/tmp}/kafka-dead-consumers.$$"

case "$FORMAT" in
  csv)
    echo "group,topic,total_lag,members,state"
    printf '%s\n' "$rows"
    ;;
  markdown)
    md_table_header "Group" "Topic" "Total Lag" "Members" "State"
    while IFS=, read -r g t l m s; do [[ -n "$g" ]] && md_table_row "$g" "$t" "$l" "$m" "$s"; done <<<"$rows"
    ;;
  table)
    printf "%-30s %-24s %-10s %-8s %-12s\n" "Group" "Topic" "Total Lag" "Members" "State"
    while IFS=, read -r g t l m s; do [[ -n "$g" ]] && printf "%-30s %-24s %-10s %-8s %-12s\n" "$g" "$t" "$l" "$m" "$s"; done <<<"$rows"
    ;;
  *) kt_die "--format must be table, csv, or markdown" ;;
esac
