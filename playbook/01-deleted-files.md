# 01 · Deleted but still open

A file with no name still exists as long as somebody holds a descriptor to it.
That single fact explains a whole family of "nothing changed but it broke"
incidents.

## The mechanic

`unlink()` removes the directory entry, not the inode. The inode's link count
drops to zero. The data and the inode survive until the last open descriptor
closes. Consequences:

- Disk space is not freed. `df` and `du` disagree and `du` is right.
- The process keeps reading and writing normally. Nothing logs an error.
- New opens fail with `ENOENT`, because there is no path to resolve.
- A restart "fixes" it, permanently destroying the evidence.

The last two together produce the symptom that wastes the most time: **the
service works for existing clients and fails for new ones.**

## Finding them

```sh
lsof -nP +L1                      # link count zero, still open
lsof -nP +L1 | awk '$5=="REG"'    # regular files only
```

Per process, when you already suspect one:

```sh
ls -l /proc/<pid>/fd | grep deleted
ls -l /proc/<pid>/cwd /proc/<pid>/exe /proc/<pid>/root   # all can be deleted
```

`/proc/<pid>/exe` pointing at `(deleted)` is the classic signature of a binary
replaced during an upgrade. The running process is still the old image; `ps`
shows the old command line; `md5sum /proc/<pid>/exe` gives you the version
that is actually running, which is not the version on disk.

## Recovering the content

```sh
cp /proc/<pid>/fd/<n> /cases/live/recovered.bin
sha256sum /cases/live/recovered.bin
```

For memory-mapped files the descriptor may not be readable as a stream; try
`/proc/<pid>/map_files/<start>-<end>` instead. If the file was sparse or huge,
copying is slow — check `ls -l /proc/<pid>/fd/<n>` first and make sure you have
the space, because you are about to duplicate something the filesystem already
thinks is gone.

## The socket variant

Unix domain sockets are files. They can be unlinked like any other file, and
the process holding them keeps working. This is the highest-value case in this
note because it is invisible to almost every monitoring system.

Detection that actually works:

```sh
ss -xlpn | grep -i sock          # kernel still remembers the path string
stat /path/from/the/output       # ...but the path no longer exists
```

If `ss` shows a path and `stat` says `No such file or directory`, you have a
live socket with no name. New clients cannot connect; established ones keep
talking.

Recovery is a restart of the owning process. **Prevention** is the part worth
writing down:

- Use the abstract namespace (`@name` instead of a path). No filesystem entry,
  nothing to delete.
- Or use systemd socket activation, which owns the socket lifecycle.
- Or, if you must clean a tmp directory on a timer, refuse to delete anything
  currently open:

```sh
for f in /tmp/*.sock; do
  [ -e "$f" ] || continue
  if lsof -nP -- "$f" >/dev/null 2>&1; then
    continue          # somebody is using it
  fi
  rm -f -- "$f"
done
```

That loop is the entire fix for the incident in
[cases/2026-10-stale-socket-500s.md](../cases/2026-10-stale-socket-500s.md).

## Reading the evidence afterwards

The deleted inode's identity survives in a few places even after the process
exits, if you collected in time:

- `lsof +L1` output with the inode number and size
- `journalctl` messages from the service around the unlink
- the cleanup script's own log, if it logs what it removed
- filesystem journals, if you image the disk (`debugfs`, `xfs_db`)

Collect first, conclude later.
