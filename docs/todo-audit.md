# Dank Todo: known limitations

The imported `1.2.0` source at `ff1b82c` is unchanged. It is experimental and is
not recommended as the sole store of important tasks. This migration does not
represent a security certification or fix these issues.

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
- Imported/manually edited cyclic parent IDs can loop indefinitely in the Active
  filter on DMS's UI thread. Normal drag operations reject cycles.
- Soft deletion while editing can discard a draft; clearing completed parents
  can leave active children indented inconsistently until reload.

The review found no explicit outbound network requests or task-text shell
execution. Tasks are plaintext JSON. Atomic writes reduce torn-file risk but do
not provide backups, conflict resolution, or recovery guarantees.

Keep independent backups of the configured Todo data directory. Prefer one
widget instance, avoid external concurrent writers, and use noncritical tasks
while evaluating. No Todo regression suite or full live UI audit is included.
