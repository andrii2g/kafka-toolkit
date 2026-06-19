#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/kafka-common.sh"
source "$ROOT_DIR/lib/markdown-table.sh"

SOURCE_BOOTSTRAP=""
TARGET_BOOTSTRAP=""
SOURCE_CONFIG=""
TARGET_CONFIG=""
TOPIC=""
FORMAT="table"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source-bootstrap) SOURCE_BOOTSTRAP="${2:-}"; shift 2 ;;
    --target-bootstrap) TARGET_BOOTSTRAP="${2:-}"; shift 2 ;;
    --topic) TOPIC="${2:-}"; shift 2 ;;
    --source-command-config) SOURCE_CONFIG="${2:-}"; shift 2 ;;
    --target-command-config) TARGET_CONFIG="${2:-}"; shift 2 ;;
    --format) FORMAT="${2:-}"; shift 2 ;;
    --help) echo "Usage: kafka-topic-config-diff.sh --source-bootstrap HOSTS --target-bootstrap HOSTS --topic TOPIC"; exit 0 ;;
    *) kt_die "unknown argument: $1" ;;
  esac
done

[[ -n "$SOURCE_BOOTSTRAP" ]] || kt_die "--source-bootstrap is required"
[[ -n "$TARGET_BOOTSTRAP" ]] || kt_die "--target-bootstrap is required"
[[ -n "$TOPIC" ]] || kt_die "--topic is required"

source_args=(--bootstrap "$SOURCE_BOOTSTRAP" --topic "$TOPIC" --format csv)
target_args=(--bootstrap "$TARGET_BOOTSTRAP" --topic "$TOPIC" --format csv)
[[ -n "$SOURCE_CONFIG" ]] && source_args+=(--command-config "$SOURCE_CONFIG")
[[ -n "$TARGET_CONFIG" ]] && target_args+=(--command-config "$TARGET_CONFIG")
source_csv="$("$SCRIPT_DIR/kafka-topic-config-report.sh" "${source_args[@]}" | tail -n +2)"
target_csv="$("$SCRIPT_DIR/kafka-topic-config-report.sh" "${target_args[@]}" | tail -n +2)"
rows="$(awk -F, '
  NR==FNR { s[$1]=$2; keys[$1]=1; next }
  { t[$1]=$2; keys[$1]=1 }
  END {
    for (k in keys) {
      if (!(k in s)) status="TARGET_ONLY";
      else if (!(k in t)) status="SOURCE_ONLY";
      else if (s[k] == t[k]) status="SAME";
      else status="DIFFERENT";
      print k "," s[k] "," t[k] "," status
    }
  }' <(printf '%s\n' "$source_csv") <(printf '%s\n' "$target_csv") | sort)"

case "$FORMAT" in
  csv)
    echo "config,source,target,status"
    echo "$rows"
    ;;
  markdown)
    md_table_header "Config" "Source" "Target" "Status"
    while IFS=, read -r k s t st; do [[ -n "$k" ]] && md_table_row "$k" "$s" "$t" "$st"; done <<<"$rows"
    ;;
  table)
    echo "Topic: $TOPIC"
    echo
    printf "%-32s %-20s %-20s %-12s\n" "Config" "Source" "Target" "Status"
    while IFS=, read -r k s t st; do [[ -n "$k" ]] && printf "%-32s %-20s %-20s %-12s\n" "$k" "$s" "$t" "$st"; done <<<"$rows"
    ;;
  *) kt_die "--format must be table, markdown, or csv" ;;
esac
