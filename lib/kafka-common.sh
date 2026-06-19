#!/usr/bin/env bash
set -euo pipefail

kt_die() {
  local message="$1"
  local code="${2:-2}"
  echo "ERROR: $message" >&2
  exit "$code"
}

kt_require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || kt_die "required command not found: $cmd"
}

kt_kafka_cmd() {
  local cmd="$1"
  if [[ -n "${KAFKA_BIN_DIR:-}" ]]; then
    printf '%s/%s\n' "$KAFKA_BIN_DIR" "$cmd"
  else
    printf '%s\n' "$cmd"
  fi
}

kt_default_bootstrap() {
  printf '%s\n' "${KAFKA_BOOTSTRAP_SERVERS:-localhost:9092}"
}

kt_add_command_config_args() {
  local config="${1:-}"
  if [[ -n "$config" ]]; then
    printf '%s\n' "--command-config"
    printf '%s\n' "$config"
  fi
}
