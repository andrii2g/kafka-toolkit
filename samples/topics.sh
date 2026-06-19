#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=../lib/kafka-common.sh
source "$ROOT_DIR/lib/kafka-common.sh"

BOOTSTRAP="$(kt_default_bootstrap)"
COMMAND_CONFIG="${KAFKA_COMMAND_CONFIG:-}"

usage() {
  cat <<'USAGE'
Usage: topics.sh [--bootstrap HOSTS] [--command-config FILE]

Create kafka-toolkit demo topics if they do not exist.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bootstrap)
      BOOTSTRAP="${2:-}"
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

KAFKA_TOPICS="$(kt_kafka_cmd kafka-topics.sh)"
kt_require_cmd "$KAFKA_TOPICS"

config_args=()
while IFS= read -r arg; do
  config_args+=("$arg")
done < <(kt_add_command_config_args "$COMMAND_CONFIG")

create_topic() {
  local topic="$1"
  local partitions="$2"
  "$KAFKA_TOPICS" \
    --bootstrap-server "$BOOTSTRAP" \
    "${config_args[@]}" \
    --create \
    --if-not-exists \
    --topic "$topic" \
    --partitions "$partitions" \
    --replication-factor 1
}

create_topic orders 6
create_topic payments 3
create_topic notifications 4
create_topic healthcheck.kafka 1
