#!/usr/bin/env bash
# Files and sockets that still exist with no name. Needs root for full coverage.
# usage: deleted-open.sh [pid]

set -euo pipefail

if [ $# -gt 0 ]; then
  lsof -nP -p "$1" +L1
  exit 0
fi

if ! command -v lsof >/dev/null 2>&1; then
  echo "lsof not installed; falling back to /proc scan (root, slower)" >&2
  for fd in /proc/[0-9]*/fd/*; do
    target=$(readlink "$fd" 2>/dev/null) || continue
    case $target in
      *"(deleted)"*|"socket:["*) printf '%s -> %s\n' "$fd" "$target" ;;
    esac
  done
  exit 0
fi

printf '%-8s %-6s %-4s %-8s %s\n' PID USER FD TYPE NAME
lsof -nP +L1 2>/dev/null | awk 'NR>1 {printf "%-8s %-6s %-4s %-8s %s %s\n", $2, $3, $4, $5, $9, $10}'
