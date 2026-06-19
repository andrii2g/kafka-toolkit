#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
exec docker compose exec -T kafka "/opt/kafka/bin/$SCRIPT_NAME" "$@"
