# 00 · Triage

Ten minutes, before you form a theory. The goal is not to understand the
machine, it is to make sure you can still understand it tomorrow.

## Do this first

```sh
CASE=/cases/$(date -u +%Y%m%dT%H%M%SZ)
mkdir -p "$CASE"/{live,logs}
exec > >(tee -a "$CASE/console.log") 2>&1
date -u +%FT%TZ            # your clock, and the host's clock, matter
uptime -s                  # boot time: everything before this is irrelevant
```

If you can, remount read-only sources with `noatime` **before** reading them,
otherwise every `cat` you run rewrites `atime` and destroys the access record
you were about to use as evidence.

## Volatile, in this order

Network first (it changes every second), then processes, then files.

```sh
ss -tanp >  "$CASE/live/ss-tcp.txt"      # listening + established, with pids
ss -uanp >  "$CASE/live/ss-udp.txt"
ss -xlpn >  "$CASE/live/ss-unix.txt"     # unix sockets, paths and inodes
ip addr  >  "$CASE/live/ip-addr.txt"
ip route >  "$CASE/live/ip-route.txt"
ip neigh >  "$CASE/live/ip-neigh.txt"
conntrack -L 2>/dev/null > "$CASE/live/conntrack.txt"

ps -eo pid,ppid,user,lstart,etime,stat,args --forest > "$CASE/live/ps.txt"
lsof -nP > "$CASE/live/lsof.txt"
lsof -nP +L1 > "$CASE/live/lsof-unlinked.txt"   # link count zero, still open
```

`lsof-unlinked.txt` is the single most under-read file in this whole process.
See [01](01-deleted-files.md).

## Then the things people forget

```sh
crontab -l; ls -la /etc/cron.* /etc/cron.d 2>/dev/null
systemctl list-timers --all --no-pager
systemctl list-units --state=failed --no-pager
mount | column -t
df -h; df -i
last -Fai | head -80
journalctl -b --no-pager > "$CASE/logs/journal-current-boot.log"
journalctl -b -1 --no-pager > "$CASE/logs/journal-previous-boot.log" 2>/dev/null
```

`df -i` is not optional: a full inode table produces failures that look like
permission problems and disk-full errors that never mention inodes.

## Write down the shape of the problem

Before touching anything else, one paragraph:

- What is broken, from the user's point of view
- When it started, and whether it is constant or periodic
- What changed around that time (deploys, cron, certificates, DNS, a reboot)
- What you have already ruled out

"Periodic" is a gift. Periodic means a timer, a cron entry, a certificate
renewal or a certificate-less client retrying. Constant means it broke once
and stayed broken.

## What not to do

- Do not restart the service to "see if it comes back" before you have
  collected. You may destroy the only copy of the state that explains it.
- Do not run `find /` while the incident is live; you will spend twenty
  minutes waiting and learn nothing.
- Do not trust `top` for anything except a rough ordering. Use `ps` with
  explicit fields.
