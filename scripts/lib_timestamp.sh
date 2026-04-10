#!/usr/bin/env bash
set -e
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

file_epoch_macos() {
  local f="$1"
  if [ -z "${f}" ] || [ ! -e "${f}" ]; then
    echo 0
    return 0
  fi
  stat -f %m "${f}" 2>/dev/null || echo 0
}

iso_to_epoch_macos() {
  local iso="$1"
  if [ -z "${iso}" ]; then
    echo 0
    return 0
  fi
  date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "${iso}" "+%s" 2>/dev/null || echo 0
}

now_epoch() {
  date +%s
}

age_seconds_from_epoch() {
  local base="$1"
  local now
  now="$(now_epoch)"
  if [ -z "${base}" ] || [ "${base}" = "0" ]; then
    echo 999999999
    return 0
  fi
  local age=$((now - base))
  if [ "${age}" -lt 0 ]; then
    age=0
  fi
  echo "${age}"
}
