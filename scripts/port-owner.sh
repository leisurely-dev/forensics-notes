#!/usr/bin/env bash
# Which process owns a listening TCP port, via the socket inode.
# Works without lsof, and when the socket's path no longer exists.
# usage: port-owner.sh 32786

set -euo pipefail

port=${1:?usage: port-owner.sh <port>}

line=$(ss -tlnpH -e "sport = :$port" 2>/dev/null || true)
if [ -z "$line" ]; then
  echo "nothing listening on tcp/$port (try sudo, or check another netns)" >&2
  exit 1
fi

printf 'listener:\n  %s\n' "$line"

inode=$(printf '%s' "$line" | grep -o 'ino:[0-9]*' | head -1 | cut -d: -f2 || true)
if [ -z "$inode" ]; then
  echo "no inode in ss output; rerun with sudo" >&2
  exit 2
fi
echo "socket inode: $inode"

echo "descriptors:"
found=0
for fd in /proc/[0-9]*/fd/*; do
  target=$(readlink "$fd" 2>/dev/null) || continue
  if [ "$target" = "socket:[$inode]" ]; then
    pid=${fd#/proc/}; pid=${pid%%/*}
    found=1
    printf '  pid %-7s %s\n' "$pid" "$(tr '\0' ' ' < "/proc/$pid/cmdline" | cut -c1-100)"
  fi
done
[ "$found" = 1 ] || echo "  none (the holder may be in another netns or has exited)"
