# 03 · Timeline

A timeline is not a list of timestamps. It is an argument about ordering, and
it only holds up if each entry says where the time came from.

## Sources, ranked by how much I trust them

| Source | Trust | Why |
|---|---|---|
| Kernel journal, monotonic + boot id | high | written by the kernel, ordered by sequence |
| systemd unit state changes | high | same |
| Application logs with explicit timestamps | medium | depends on the app's clock and buffering |
| `st_birthtime` (statx, `%w`) | medium | set at creation, hard to fake, often unsupported |
| `mtime` / `ctime` | low | `mtime` is settable, `ctime` moves on any metadata change |
| Shell history | low | no ordering, easily edited |
| Anything from a process that had a wrong clock | useless | check `timedatectl` and NTP state first |

If the host's clock was wrong during the incident, say so at the top of the
report and anchor everything to boot time and journal sequence instead.

## Cheap and usually enough

```sh
journalctl --since "2026-10-29 00:00" --until "2026-10-30 00:00" \
  -o short-iso-precise --no-pager > /cases/live/journal-window.log
```

`short-iso-precise` keeps microseconds and the timezone offset. Losing the
offset is how two logs from different hosts end up in the wrong order.

## Files changed in a window

```sh
find / -xdev -newermt "2026-10-29 22:00" ! -newermt "2026-10-30 02:00" \
  -printf '%TY-%Tm-%TdT%TH:%TM:%TS %p\n' 2>/dev/null | sort
```

Add birth time where the filesystem supports it:

```sh
find / -xdev -newermt "2026-10-29 22:00" -printf '%w %TY-%Tm-%TdT%TH:%TM %p\n' 2>/dev/null
```

`%w` prints `-` when birth time is unavailable (ext4 with older kernels,
tmpfs before 4.19). A dash is information: it tells you that for this file,
you cannot distinguish "created then" from "created earlier and modified then".

## Ordering across sources

The hard part is merging a journal line, an access log line and a file mtime
into one sequence. Normalise to UTC, keep the source in a column, and never
sort by a single field:

```
ts_utc                 source        event
2026-10-29T22:14:03Z   cron          clean_caches.sh started
2026-10-29T22:14:03Z   kernel        unlink /tmp/app.sock
2026-10-29T22:14:07Z   nginx         upstream connect failed (ENOENT)
```

Two entries with the same second are not ordered. Do not pretend they are.

## When you need a real tool

For disk images rather than a live host:

```sh
# body file from an image, then sort by time
fls -r -m / -o 2048 disk.dd > bodyfile.txt
mactime -b bodyfile.txt -d -z UTC 2026-10-29..2026-10-30 > timeline.csv
```

```sh
# plaso, when the sources are heterogeneous (evtx, syslog, browser, shellbags)
log2timeline.py /cases/out.plaso /cases/artifact-dir
psort.py -o l2tcsv -w /cases/timeline.csv /cases/out.plaso
```

Super-timelines get large fast. Filter by window first, widen later if the
story does not close.

## The two mistakes

1. **Sorting mixed-timezone logs as strings.** `2026-10-29 22:14:03+08:00`
   sorts before `2026-10-29 15:14:03Z` and means the same instant.
2. **Trusting `mtime` as creation time.** A `touch -d` costs nothing. If the
   ordering of two files matters, get birth time or find another witness.
