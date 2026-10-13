# Dank Todo: known limitations

The local `1.3.0-local.1` version is based on imported `1.2.0` at `ff1b82c`.
It adds translations, tree rendering, time fields and pause/resume, but remains
experimental and is not recommended as the sole store of important tasks.
This is not a security certification.

Read-only review of both QML files and DMS v1.6.3 host code, plus extracted
JavaScript logic checks, identified:

- Invalid JSON is treated as an empty list. The next modification can overwrite
  damaged data instead of protecting it for recovery.
- Every widget instance owns a private list and writes the entire file.
  Multiple screens/bars can overwrite changes with stale snapshots. Opening a
  popout reloads data, mitigating sequential GUI usage, not concurrent writers.
  Actual simultaneous-window behavior and duplicate IPC routing were not tested.
- Writes are asynchronous and have no save-failure handler; reported UI/IPC
  success does not confirm durable storage. Real disk-full/permission failures
  were not injected into a running desktop.
- Reducing the text-length limit truncates existing entries on load; the next
  write persists the truncation.
- Soft deletion while editing cancels the draft for that item.

The local loader now breaks cyclic parent references. Tree rows follow parent
relationships rather than relying on contiguous array order; filtered views keep
ancestor rows as context. Clearing completed parents promotes unfinished children
to the nearest surviving ancestor. Headless QML regressions cover these paths,
time fields and pause/resume; they do not exercise simultaneous real widget writers.

The review found no explicit outbound network requests or task-text shell
execution. Tasks are plaintext JSON. Atomic writes reduce torn-file risk but do
not provide backups, conflict resolution, or recovery guarantees.

Keep independent backups of the configured Todo data directory. Prefer one
widget instance, avoid external concurrent writers, and use noncritical tasks
while evaluating. A full live-session UI audit is not included.
