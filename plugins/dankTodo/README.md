# Dank Todo — Linear

A small DMS bar client for **your assigned Linear issues**, locally maintained as
`2.0.0-local.2`. Requires DMS 1.6.3 or later. Install from this checkout using the
[repository instructions](../../README.md), not the upstream plugin registry.

## What it does

- Shows your non-archived issues in a collapsible tree, with ancestors as context.
- Opens on pending issues, with a separate closed view; completed, canceled and
  duplicate are closed.
- Completes a single assigned issue using its team's native completed state.
- Shows titles, identifiers, team workflow states and due dates (`YYYY-MM-DD`).
- Shows native creation/completion times in the “Open in Linear” tooltip.
- Follows DMS's locale with English fallback and Simplified Chinese translations.

The shared daemon owns requests and state, so multiple bar instances use the same
snapshot. Refresh on opening the popout or with the refresh button. There is no
background polling, local task store, offline write queue, custom pause state,
drag reordering, creation, editing, reopening, remote deletion, or local-to-Linear
import.
Create and edit tasks in Linear's website or other tools, not this plugin.

Only pending issues assigned to you can be completed here. Ancestor rows can
belong to other people and are displayed only for context. The list is paginated until complete;
archived issues and other people's subtasks are not fetched as your tasks.
Linear's own workflow rules apply, including any parent/sub-issue automation.

## API key

Create a personal API key in Linear's **Settings → Security & access** with
permission to read issues/team metadata and update issues in the teams you
intend to use. See [Linear's authentication documentation](https://linear.app/developers/graphql).
Do not share the key in chat, Git, screenshots, or shell command arguments.

Put **only the key** in a private plain-text file, default:

```text
$XDG_CONFIG_HOME/dank-todo/linear-api-key
# when XDG_CONFIG_HOME is unset: ~/.config/dank-todo/linear-api-key
```

Create it using a local editor with `umask 077`; restrict the file to your user
(`chmod 600 /path/to/linear-api-key`). This plugin reads the file; it never creates
or writes it. The settings page stores only its path. Paths must be absolute;
`~` and shell variables are not expanded.

In DMS plugin settings, choose the key file, reload the connection and select the
bar count display. The title remains **Dank Todo** and the plugin ID remains
`dankTodo`, preserving your existing bar placement.

All API requests go to `https://api.linear.app/graphql` over HTTPS. Keys remain
in process memory, never in task data, plugin settings, logs, or IPC output.
The plugin has no OAuth flow and no credential permission-enforcement sandbox;
protect the file and your desktop account.

## Completing a task

Click the circle beside a pending task to complete it. The plugin sends only a
state change, choosing the first `completed` state in the team's workflow order.
It does not change the title, assignee, due date, or children itself. Any parent/
sub-issue automation configured in Linear still applies. If a team has no
completed state, the action is disabled and the row explains why.
Closed tasks and parent-context rows are read-only; use “Open in Linear” for
other operations. The closed view preserves each task's native state label,
including canceled and duplicate rather than calling those tasks completed.

Requests are serialized across bar instances. The list changes only after
Linear confirms the state change and returns a refreshed snapshot. A timeout
may occur after a write reached the server:
**refresh and check Linear before retrying**.
There are no automatic mutation retries. A failed refresh preserves the previous
snapshot with an error; it does not pretend the data is current.
Changing credentials cancels outstanding requests and clears the account snapshot;
late responses cannot populate a different account.

## Upgrade from the local TODO version

This is a replacement, not a sync adapter. Existing `todos.json` files are
**left untouched**, not read, uploaded, migrated, or deleted. Old storage/limit
preferences and the former default-team setting no longer affect this plugin.
Keep independent backups if you want
to return to the local version. No Linear issues are changed merely by upgrading.

Legacy write IPC commands are removed. The shared daemon exposes only:

```sh
dms ipc call dankTodo refresh  # STARTED or NOT_STARTED; asynchronous
dms ipc call dankTodo list     # current in-memory personal issues, no credentials
dms ipc call dankTodo count    # active/total
```

## Verification

`sh tests/check-source.sh` includes mocked GraphQL transport checks and headless
QML tests for the shared service, widget/settings, completion and translations.
They make no real Linear requests and do not read your key or task files.
Real account permissions, desktop rendering and live server behavior still need
an explicitly authorized live-session check.

## License

MIT; upstream notices are preserved.
