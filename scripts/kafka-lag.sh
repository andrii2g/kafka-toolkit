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
FORMAT="table"

usage() {
  cat <<'USAGE'
Usage: kafka-lag.sh --group GROUP [--topic TOPIC] [--bootstrap HOSTS] [--command-config FILE] [--format table|csv|json]

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
    --format)
      FORMAT="${2:-}"
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
[[ "$FORMAT" == "table" || "$FORMAT" == "csv" || "$FORMAT" == "json" ]] || kt_die "--format must be table, csv, or json"

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

if [[ "$FORMAT" == "csv" ]]; then
  awk -F, 'BEGIN { OFS="," } NR == 1 { print "group","topic","partition","current_offset","log_end_offset","lag"; next } { print $1,$2,$3,$4,$5,$6 }' <<<"$csv"
  exit 0
fi

if [[ "$FORMAT" == "json" ]]; then
  kt_require_cmd jq
  awk -F, 'NR > 1 { print }' <<<"$csv" | jq -R -s --arg group "$GROUP" --arg topic "$TOPIC" '
    split("\n")[:-1]
    | map(split(","))
    | {
        group: $group,
        topic: (if $topic == "" then null else $topic end),
        totalLag: (map(.[5] | if . == "" then 0 else tonumber end) | add // 0),
        partitions: map({
          group: .[0],
          topic: .[1],
          partition: (.[2] | tonumber),
          currentOffset: (if .[3] == "" then null else (.[3] | tonumber) end),
          logEndOffset: (if .[4] == "" then null else (.[4] | tonumber) end),
          lag: (if .[5] == "" then null else (.[5] | tonumber) end)
        })
      }'
  exit 0
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
