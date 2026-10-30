# 04 · Memory

Only worth doing while the machine is still up, and only worth doing if you
have somewhere to put the image. A full capture of a 32 GB host is 32 GB; plan
before you type the command.

## What memory gives you that disk does not

- Processes that never wrote a log line
- Decrypted keys and session material
- Command lines and environment of short-lived processes
- Sockets and connections that were closed before you ran `ss`

What it does not give you: a stable, reproducible answer. Memory changes while
you copy it, and every tool will report slightly different process lists.

## Acquisition on a live host

```sh
# Microsoft AVML - static binary, no kernel module, works on most distros
wget -q https://github.com/microsoft/avml/releases/latest/download/avml
chmod +x avml
sudo ./avml /cases/live/memory.lime
sha256sum /cases/live/memory.lime | tee /cases/live/memory.sha256
```

LiME needs a kernel module built against the running kernel, which is often
more trouble than it is worth on a production box. AVML avoids that.

Record before and after:

```sh
date -u +%FT%TZ; free -m; cat /proc/meminfo | head -5
```

## Analysis

```sh
pip install volatility3
vol -f memory.lime linux.pslist
vol -f memory.lime linux.pstree
vol -f memory.lime linux.bash          # shell history from memory, often better than .bash_history
vol -f memory.lime linux.lsof
vol -f memory.lime linux.sockstat
vol -f memory.lime linux.malfind
```

`linux.bash` is the one that pays for the whole exercise. It reads the history
buffer out of each bash process, including commands typed in a session that
never flushed to disk.

## Correlate, do not conclude

A process in `linux.pslist` that is absent from the on-disk `ps` output means
one of two things: it exited between collections, or it was hidden. The
difference is in the start time, the parent, and whether the pid appears in
`/proc` at the moment you looked.

Write both collections down with their timestamps. "Missing from memory" is not
a finding without a time attached to it.

## Practical notes

- Capture to a different filesystem than the one under investigation, or to
  network storage, so you do not overwrite freed blocks you might want later.
- `madvise(MADV_DONTNEED)` and ballooning in VMs can zero pages you wanted.
  On a VM, snapshot from the hypervisor instead of from inside the guest.
- Do not run the acquisition binary from the compromised box's own disk if you
  can help it. Carry a known-good copy.
