#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=../lib/kafka-common.sh
source "$ROOT_DIR/lib/kafka-common.sh"

BOOTSTRAP="$(kt_default_bootstrap)"
COMMAND_CONFIG="${KAFKA_COMMAND_CONFIG:-}"
GROUP=""
TOPIC=""

usage() {
  cat <<'USAGE'
Usage: kafka-lag.sh --group GROUP [--topic TOPIC] [--bootstrap HOSTS] [--command-config FILE]

Show consumer group lag using kafka-consumer-groups.sh.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bootstrap)
      BOOTSTRAP="${2:-}"
      shift 2
      ;;
    --group)
      GROUP="${2:-}"
      shift 2
      ;;
    --topic)
      TOPIC="${2:-}"
      shift 2
      ;;
    --command-config)
      COMMAND_CONFIG="${2:-}"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      kt_die "unknown argument: $1"
      ;;
  esac
done

[[ -n "$GROUP" ]] || kt_die "--group is required"

KAFKA_CONSUMER_GROUPS="$(kt_kafka_cmd kafka-consumer-groups.sh)"
kt_require_cmd "$KAFKA_CONSUMER_GROUPS"

config_args=()
while IFS= read -r arg; do
  config_args+=("$arg")
done < <(kt_add_command_config_args "$COMMAND_CONFIG")

raw="$("$KAFKA_CONSUMER_GROUPS" \
  --bootstrap-server "$BOOTSTRAP" \
  "${config_args[@]}" \
  --describe \
  --group "$GROUP")"

csv="$(awk -f "$ROOT_DIR/lib/kafka-lag-parser.awk" <<<"$raw")"

if [[ -n "$TOPIC" ]]; then
  csv="$(awk -F, -v topic="$TOPIC" 'NR == 1 || $2 == topic { print }' <<<"$csv")"
fi

awk -F, -v group="$GROUP" -v topic="$TOPIC" '
  NR == 1 { next }
  {
    rows[++count] = $0
    total += ($6 == "" ? 0 : $6)
  }
  END {
    print "Group: " group
    if (topic != "") {
      print "Topic: " topic
    }
    print ""
    printf "%-10s %-15s %-15s %-10s\n", "Partition", "Current Offset", "End Offset", "Lag"
    for (i = 1; i <= count; i++) {
      split(rows[i], f, ",")
      printf "%-10s %-15s %-15s %-10s\n", f[3], f[4], f[5], f[6]
    }
    print ""
    print "Total lag: " total
  }
' <<<"$csv"
