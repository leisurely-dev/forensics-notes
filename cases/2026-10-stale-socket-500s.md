# 2026-10 · Periodic 500s from a socket nobody owned

**Status:** closed, fix deployed
**Impact:** one production host, one HTTP service, intermittent 500s for
external clients only
**Time to root cause:** about 40 minutes, of which 35 were spent looking in the
wrong place

## Summary

A small service sat behind a TCP listener on a high port. Every few minutes it
returned `500` to new clients while its own health check, which used an
already-open connection, stayed green. The process was alive, the port was
listening, and no error appeared anywhere until the moment of failure.

The cause was a cache-cleaning script on a timer that ran

```sh
rm -f /tmp/*.sock
```

The application's listening socket was a **unix domain socket** at
`/tmp/app.sock`. Deleting the file did not close the socket: the process still
held the descriptor, so existing connections kept working normally. But the
path was gone, so every *new* connection attempt failed with `ENOENT` before it
ever reached the application. Whatever sat in front of the service saw the
failure and returned `500`.

Restarting the service "fixed" it every time, which is exactly why it took so
long to find: the restart rebinds the path, the evidence disappears, and the
next timer tick brings it back.

## What it looked like

- `systemctl status`: active (running), uptime days
- health endpoint: 200, always
- port check from outside: listening
- application log: nothing between clean starts
- client report: "it fails for a few seconds, then works again"

The health check was the trap. It reused a pooled connection, so it never
exercised the path that was broken.

## How it was found

Two commands, in this order:

```sh
ss -xlpn | grep app.sock
# u_str LISTEN 0 4096 /tmp/app.sock 1234567 * 0 users:(("app",pid=20431,fd=9))

stat /tmp/app.sock
# stat: cannot statx '/tmp/app.sock': No such file or directory
```

A socket the kernel is listening on, whose path does not exist. That
contradiction is the whole finding. Confirmation:

```sh
lsof -nP -p 20431 +L1
# app 20431 root 9u unix 0x... 0t0 1234567 /tmp/app.sock (deleted)
```

`(deleted)` with a link count of zero, held open by pid 20431.

## Root cause

Two individually reasonable decisions:

1. The service used a filesystem-path unix socket in `/tmp`, because that was
   the simplest thing that worked when it was written.
2. A cleanup script removed stale sockets from `/tmp` on a timer, because
   sockets left behind by crashed processes do accumulate.

Neither is wrong alone. Together they delete the listening socket of a healthy
process, and nothing in either program reports a problem: `rm` succeeds, the
daemon logs nothing, the kernel keeps the socket alive.

## Fix

Short term: stop the timer, restart the service, path is rebound.

Long term, in the order I would do them again:

1. **Move the socket to the abstract namespace** (`@app.sock`). No filesystem
   entry exists, so no cleanup script can remove it. This is the real fix.
2. If a path is required, let the cleanup script check before it deletes:

```sh
for f in /tmp/*.sock; do
  [ -e "$f" ] || continue
  lsof -nP -- "$f" >/dev/null 2>&1 && continue
  rm -f -- "$f"
done
```

3. Make the health check open a new connection each time. A check that cannot
   fail is not a check.

## What I would do differently

- When a symptom is "intermittent and self-healing", the first question is
  "what runs on a timer", not "what is wrong with the code". `systemctl
  list-timers --all` and `crontab -l` take ten seconds and would have ended
  this in five minutes.
- The green health check should have been treated as a suspect, not as
  evidence of health. It answered a different question than the one being
  asked.
- Collect before restarting. The first restart destroyed a clean reproduction
  and I only got the `(deleted)` output on the third occurrence because I
  stopped myself from typing `systemctl restart`.

## Related

- [Deleted but still open](../playbook/01-deleted-files.md)
- [Sockets, ports, inodes](../playbook/02-sockets.md)

---

*Host identity, addresses and exact timestamps removed. The mechanism is
unchanged; the numbers were never the interesting part.*
