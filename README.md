# forensics-notes

Notes and scripts I keep for Linux server incidents: the thirty minutes after
someone says "it started returning 500s again", and the slower work of working
out what actually happened.

Most of this comes from machines I run, so the bias is towards small,
single-host incidents rather than enterprise IR. Everything here is written to
be run by one person over SSH with nothing but coreutils, procps, iproute2 and
lsof.

## Ground rules

1. **Snapshot before you investigate.** The first command you run changes the
   system. Copy volatile state out before you start grepping.
2. **Timestamps lie more than people do.** `mtime` is settable by anyone with
   `utimes()`. Prefer birth time (`statx`, `find -printf '%w'`), journal
   ordering, and cross-correlated sources.
3. **A process that is alive is not a service that works.** Sockets, deleted
   inodes and file descriptors outlive the paths that pointed at them.
4. **Write down what you ruled out.** The negative results are the expensive
   part and the part you will forget.

## Playbooks

| # | Note | Use it when |
|---|---|---|
| 00 | [Triage](playbook/00-triage.md) | Something is wrong right now and you have ten minutes |
| 01 | [Deleted but still open](playbook/01-deleted-files.md) | A file vanished, a service broke, nothing restarted |
| 02 | [Sockets, ports, inodes](playbook/02-sockets.md) | "The port is listening but nothing answers" |
| 03 | [Timeline](playbook/03-timeline.md) | You need to know what changed, in what order |
| 04 | [Memory](playbook/04-memory.md) | You need what was never written to disk |

## Cases

Real incidents, written up after the fact, with the parts that made them
interesting kept and the identifying details removed.

- [2026-10: periodic 500s from a socket nobody owned](cases/2026-10-stale-socket-500s.md)

New write-ups follow [the template](cases/TEMPLATE.md).

## Scripts

```sh
scripts/triage.sh /cases/2026-10-30        # collect volatile state into a directory
scripts/deleted-open.sh                    # everything still held open after unlink
scripts/port-owner.sh 32786                # port -> socket inode -> pid -> cmdline
```

They are read-only apart from writing into the output directory you pass.

## Scope

Single Linux host, no hypervisor-level collection, no malware reversing. If a
case turns into either of those, the notes say so and stop rather than pretend.

MIT licensed. Corrections welcome, especially where a command is wrong for
your distro.
