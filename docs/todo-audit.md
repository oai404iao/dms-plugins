# Dank Todo: Linear rewrite and limits

`2.0.0-local.2` narrows the Linear implementation to viewing and completing your
assigned tasks, without a composer or arbitrary editing. The Linear rewrite
replaces the local JSON TODO implementation. The original MIT license and plugin
ID are retained. Existing task files are not opened, uploaded or changed.

The shared daemon keeps one in-memory snapshot and serializes requests across bar
instances. Task writes go through Linear's GraphQL API and are acknowledged by the
server before a subsequent refresh updates the list. There is no offline write queue,
local task-file writer, or automatic mutation retry.

## Remaining limits

- A request timeout or lost response does not prove a mutation failed. Refresh
  and check Linear before repeating a completion request.
- A failed refresh retains the previous snapshot and shows an error. Manual
  refresh and popout opening refresh it; there is no polling or webhook listener.
- Only non-archived issues assigned to the authenticated user are listed.
  Ancestors are read for context, not made completable. Other people's sub-issues
  are not fetched as your tasks.
- Credential files must be protected by the user. The plugin reads a key into
  memory and does not enforce file modes or provide encrypted credential storage.
  The key path, not the key, is stored in DMS settings.
- Changing credentials clears the snapshot and cancels in-flight work. Late
  replies cannot repopulate the previous account.
- Workflow behavior belongs to Linear, including team-specific states and
  parent/sub-issue automation. There is no independently maintained pause state.
- Completion sends only `stateId`, using the first `completed` state in the
  team's workflow order. Teams without such a state cannot be completed here.
  Closed tasks cannot be reopened; creation and editing belong to other tools.
- Headless tests use stub IO and mocked GraphQL replies. They do not verify real
  account permissions, API availability, rate-limit timing, or live DMS layout.

Requests use a fixed HTTPS endpoint, GraphQL variables for user input, and safe
error messages that do not echo server details or credentials. Ordinary read
pagination is supported; team workflow states exceeding one 100-state page cause
an explicit failed refresh rather than silently hiding state choices.

This is not a security certification. Follow the
[plugin setup and upgrade instructions](../plugins/dankTodo/README.md).
