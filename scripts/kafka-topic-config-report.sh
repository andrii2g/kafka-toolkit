#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/kafka-common.sh"
source "$ROOT_DIR/lib/markdown-table.sh"

BOOTSTRAP="$(kt_default_bootstrap)"
COMMAND_CONFIG="${KAFKA_COMMAND_CONFIG:-}"
TOPIC=""
OUT="-"
FORMAT="markdown"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bootstrap) BOOTSTRAP="${2:-}"; shift 2 ;;
    --topic) TOPIC="${2:-}"; shift 2 ;;
    --out) OUT="${2:-}"; shift 2 ;;
    --format) FORMAT="${2:-}"; shift 2 ;;
    --command-config) COMMAND_CONFIG="${2:-}"; shift 2 ;;
    --help) echo "Usage: kafka-topic-config-report.sh --topic TOPIC [--out FILE] [--format markdown|table|csv]"; exit 0 ;;
    *) kt_die "unknown argument: $1" ;;
  esac
done

[[ -n "$TOPIC" ]] || kt_die "--topic is required"
KAFKA_CONFIGS="$(kt_kafka_cmd kafka-configs.sh)"
kt_require_cmd "$KAFKA_CONFIGS"
config_args=()
while IFS= read -r arg; do config_args+=("$arg"); done < <(kt_add_command_config_args "$COMMAND_CONFIG")
raw="$("$KAFKA_CONFIGS" --bootstrap-server "$BOOTSTRAP" "${config_args[@]}" --entity-type topics --entity-name "$TOPIC" --describe)"
configs="$(grep -oE '[A-Za-z0-9._-]+=[^, ]+' <<<"$raw" | sort || true)"

{
  case "$FORMAT" in
    csv)
      echo "config,value"
      while IFS== read -r key value; do [[ -n "$key" ]] && echo "$key,$value"; done <<<"$configs"
      ;;
    table)
      printf "%-32s %s\n" "Config" "Value"
      while IFS== read -r key value; do [[ -n "$key" ]] && printf "%-32s %s\n" "$key" "$value"; done <<<"$configs"
      ;;
    markdown)
      echo "# Kafka Topic Config Report"
      echo
      echo "Generated UTC: \`$(kt_timestamp_utc)\`"
      echo
      echo "Topic: \`$TOPIC\`"
      echo
      md_table_header "Config" "Value"
      while IFS== read -r key value; do [[ -n "$key" ]] && md_table_row "$key" "$value"; done <<<"$configs"
      echo
      echo '```text'
      echo "$raw"
      echo '```'
      ;;
    *) kt_die "--format must be markdown, table, or csv" ;;
  esac
} | kt_write_output "$OUT"
