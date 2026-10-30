# 02 · Sockets, ports, inodes

"The port is listening but nothing answers" is four different problems wearing
the same sentence. This note is about telling them apart.

## Map port to process without guessing

```sh
ss -tlnp 'sport = :32786'
# LISTEN 0 4096 0.0.0.0:32786 0.0.0.0:* users:(("svc",pid=1234,fd=7))
```

If `ss` shows no process but you know something is listening, you are not root,
or the socket belongs to a different network namespace. Check both:

```sh
sudo ss -tlnp 'sport = :32786'
sudo nsenter -t 1 -n ss -tlnp | grep 32786
```

Containers are the usual explanation: the listener is in another netns, so it
is invisible from the host namespace and shows up only after `nsenter` or
`docker exec`.

## Inode is the join key

Every socket has an inode. Every descriptor points at an inode. `/proc` lets
you walk the other direction, from inode to process, without `lsof`:

```sh
inode=$(ss -tlnpH -e 'sport = :32786' | grep -o 'ino:[0-9]*' | cut -d: -f2)
ls -l /proc/*/fd/* 2>/dev/null | grep "socket:\[$inode\]"
```

That trick works when `lsof` is missing, when the process is wedged, and when
you want to prove a descriptor is still held by a process that claims to have
closed it.

## The four failure shapes

| Symptom | Likely cause | Check |
|---|---|---|
| `LISTEN` present, connects hang | accept queue full, or process wedged | `ss -tln` Recv-Q, stack of the process |
| `LISTEN` present, connects get RST | firewall rejecting, not the app | `iptables -S`, `nft list ruleset` |
| `ss` shows the path, `stat` fails | unlinked unix socket | [01](01-deleted-files.md) |
| nothing listening, app says healthy | app bound to loopback only, or wrong netns | `ss -tlnp`, `nsenter` |

`ss -tln` with `Recv-Q` at the backlog limit is the one people misdiagnose as
"the app is slow". It is not slow, it is not accepting.

## Connection states worth knowing

```
SYN-SENT      client is trying, no answer yet (packets dropped, not refused)
ESTABLISHED   both ends agree; says nothing about whether the app read the bytes
CLOSE-WAIT    peer closed, local app has not closed yet -> descriptor leak
TIME-WAIT     normal teardown, not a bug
FIN-WAIT-2    peer closed and we ACKed, peer never sent FIN -> usually peer's bug
```

A pile of `CLOSE-WAIT` on one service means that service is leaking file
descriptors, and it will eventually hit its `ulimit -n` and start refusing.
Count them before you count connections:

```sh
ss -tan state close-wait | wc -l
```

## Unix sockets, the parts that matter

```sh
ss -xlpn | column -t
```

- `@name` is the abstract namespace: no filesystem entry, cannot be unlinked,
  scoped to the network namespace. Prefer it.
- A path socket is limited by path length (`sun_path`, 108 bytes). Long
  container paths silently truncate.
- Permissions come from the file's mode, so an unlinked socket has no
  permissions at all — that is another way to notice.
- `SO_PEERCRED` lets the server identify the client's uid/pid. Useful, and
  worth knowing exists when a "who is calling me" question comes up.

## Before you blame the network

```sh
curl -sv --max-time 5 http://127.0.0.1:32786/ 2>&1 | tail -20
```

Loopback removes DNS, TLS, proxies, load balancers and the firewall from the
picture in one step. If loopback works and the public address does not, the
application was never the problem.
