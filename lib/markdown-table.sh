#!/usr/bin/env bash

md_escape() {
  local value="$1"
  printf '%s' "${value//|/\\|}"
}

md_table_header() {
  local first=1
  local col
  for col in "$@"; do
    if [[ "$first" -eq 1 ]]; then
      printf '| %s ' "$(md_escape "$col")"
      first=0
    else
      printf '| %s ' "$(md_escape "$col")"
    fi
  done
  printf '|\n'
  for col in "$@"; do
    printf '|---'
  done
  printf '|\n'
}

md_table_row() {
  local col
  for col in "$@"; do
    printf '| %s ' "$(md_escape "$col")"
  done
  printf '|\n'
}
