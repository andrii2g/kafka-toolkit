#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/kafka-common.sh"

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
    --help) echo "Usage: kafka-group-state.sh --group GROUP [--format table|csv|json]"; exit 0 ;;
    *) kt_die "unknown argument: $1" ;;
  esac
done

[[ -n "$GROUP" ]] || kt_die "--group is required"
KAFKA_CONSUMER_GROUPS="$(kt_kafka_cmd kafka-consumer-groups.sh)"
kt_require_cmd "$KAFKA_CONSUMER_GROUPS"
config_args=()
while IFS= read -r arg; do config_args+=("$arg"); done < <(kt_add_command_config_args "$COMMAND_CONFIG")

raw="$("$KAFKA_CONSUMER_GROUPS" --bootstrap-server "$BOOTSTRAP" "${config_args[@]}" --describe --group "$GROUP" --state)"
row="$(awk -v group="$GROUP" '$1 == group { print; exit }' <<<"$raw")"
[[ -n "$row" ]] || kt_die "group state not found for $GROUP"
state="$(awk '{ print $(NF-1) }' <<<"$row")"
members="$(awk '{ print $NF }' <<<"$row")"
assignment="$(awk '{ print $(NF-2) }' <<<"$row")"
kt_is_number "$members" || members=0

case "$FORMAT" in
  csv)
    echo "group,state,members,assignment_strategy"
    echo "$GROUP,$state,$members,$assignment"
    ;;
  json)
    kt_require_cmd jq
    jq -n --arg group "$GROUP" --arg state "$state" --argjson members "${members:-0}" --arg assignment "$assignment" \
      '{group:$group,state:$state,members:$members,assignmentStrategy:$assignment}'
    ;;
  table)
    printf "%-24s %-14s %-8s %-20s\n" "Group" "State" "Members" "Assignment"
    printf "%-24s %-14s %-8s %-20s\n" "$GROUP" "$state" "$members" "$assignment"
    ;;
  *) kt_die "--format must be table, csv, or json" ;;
esac
