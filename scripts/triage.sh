#!/usr/bin/env bash
# Collect volatile state into a directory. Read-only apart from the output dir.
# usage: triage.sh /cases/2026-10-30T11-00Z

set -euo pipefail

out=${1:?usage: triage.sh <output-dir>}
mkdir -p "$out"/{live,logs}

say() { printf '%s\n' "$*"; }

say "collecting into $out"
date -u +%FT%TZ > "$out/live/collected-at.txt"
uptime -s > "$out/live/boot-time.txt" 2>/dev/null || true
hostnamectl 2>/dev/null > "$out/live/hostnamectl.txt" || true
uname -a > "$out/live/uname.txt"

# network first, it changes fastest
ss -tanp > "$out/live/ss-tcp.txt" 2>/dev/null || true
ss -uanp > "$out/live/ss-udp.txt" 2>/dev/null || true
ss -xlpn > "$out/live/ss-unix.txt" 2>/dev/null || true
ip addr  > "$out/live/ip-addr.txt" 2>/dev/null || true
ip route > "$out/live/ip-route.txt" 2>/dev/null || true
ip neigh > "$out/live/ip-neigh.txt" 2>/dev/null || true
conntrack -L > "$out/live/conntrack.txt" 2>/dev/null || true

# processes and descriptors
ps -eo pid,ppid,user,lstart,etime,stat,args --forest > "$out/live/ps.txt"
lsof -nP > "$out/live/lsof.txt" 2>/dev/null || say "warn: lsof unavailable, lsof.txt is empty"
lsof -nP +L1 > "$out/live/lsof-unlinked.txt" 2>/dev/null || true

# storage and mounts
mount > "$out/live/mounts.txt"
df -h > "$out/live/df.txt"
df -i > "$out/live/df-inodes.txt"

# scheduling, the usual suspect for anything periodic
crontab -l > "$out/live/crontab.txt" 2>/dev/null || true
ls -la /etc/cron.d /etc/cron.daily 2>/dev/null > "$out/live/cron-dirs.txt" || true
systemctl list-timers --all --no-pager > "$out/live/systemd-timers.txt" 2>/dev/null || true
systemctl list-units --state=failed --no-pager > "$out/live/systemd-failed.txt" 2>/dev/null || true

# logs
journalctl -b --no-pager > "$out/logs/journal-current-boot.log" 2>/dev/null || true
journalctl -b -1 --no-pager > "$out/logs/journal-previous-boot.log" 2>/dev/null || true
last -Fai 2>/dev/null | head -100 > "$out/logs/last.txt" || true

say "done. start with $out/live/lsof-unlinked.txt and $out/live/systemd-timers.txt"
