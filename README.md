# DMS plugins

[中文](README.zh-CN.md)

Maintained source monorepo for `oai404iao/dms-plugins`. Each directory under
`plugins/` is an independent DMS plugin; no nested Git repositories are needed.

| Component | Role |
| --- | --- |
| `plugins/lyrics` | Shared bilingual lyrics daemon, locally maintained version `0.4.0-local.1` |
| `plugins/dankTodo` | Dank Todo `2.0.0-local.1`: your Linear issues, native states and sub-issues; read the [setup](plugins/dankTodo/README.md) and [limits](docs/todo-audit.md) |
| `scripts/dms-media-lyrics` | Version-pinned native media bar/page overlay |
| `scripts/prepare-dms-media-lyrics.py` | Offline preparation of a separate shell tree |
| `bin/dms-with-lyrics` | Version-matched launcher with stock-DMS fallback |

## Ownership and provenance

This repository owns plugin source, the overlay, launcher, installer, and tests.
Dotfiles/chezmoi owns desktop configuration, not a second copy of these sources.
DMS enablement, bar layout, preferences, plugin lockfiles, caches, credentials,
and Linear API keys remain machine-local. Never commit them. Old
`~/.config/dank-todo/todos.json` files remain untouched by the Linear rewrite.
See [provenance and licenses](docs/provenance.md); upstream licenses are retained.
Todo is locally maintained; see its [usage and data format](plugins/dankTodo/README.md).

The lyrics daemon queries NetEase and LRCLIB using playback metadata, with no
API key or AI service. Provider availability and translations are not guaranteed.
It is not a separate bar widget: the prepared overlay integrates it into native
media UI. Chinese settings translations do not translate song lyrics themselves.

## Local installation

Requires Python 3, DMS, and a persistent checkout. The reviewed lyrics overlay
supports **DMS v1.6.2 and v1.6.3 only**; other versions are deliberately rejected.
Clone this repository to a development directory, not inside DMS's plugin folder.
From its root:

```sh
sh tests/check-source.sh
python3 scripts/install.py --dry-run
python3 scripts/install.py
```

The installer links exactly:

- `$XDG_CONFIG_HOME/DankMaterialShell/plugins/lyrics` (default `~/.config/...`);
- `$XDG_CONFIG_HOME/DankMaterialShell/plugins/dankTodo`;
- `~/.local/bin/dms-with-lyrics`.

Existing files, directories (including `.git`), and symlinks are moved intact to
a fresh mode-0700 directory under `~/.local/state/agents/tmp/dms-plugins-install.*`.
The installer prints every backup path, refuses cross-filesystem backup renames,
and is idempotent. It rejects destinations overlapping its source repository.
It never deletes backups/data, fetches code, changes preferences, prepares the
overlay, enables plugins, or restarts DMS. A failure may leave partial installation;
inspect printed paths and preserve backups before retrying. Keep the checkout at
its installed location. Install before starting the DMS session where practical.

For an existing dotfiles installation, first retire its old source ownership
using that repository's migration instructions; otherwise a later apply could
overwrite these links. The installer does not modify chezmoi or Niri configuration.
Keep `~/.local/bin` on the session PATH.

## Prepare the lyrics overlay

Use a trusted, complete, pristine extracted shell tree from the installed
supported DMS release. While stock DMS is running, `qs list --all` can identify
its extraction path. Do not use an already overlaid tree:

```sh
python3 scripts/prepare-dms-media-lyrics.py /path/to/pristine/extracted/dms-shell
```

This checks release and exact hashes of `shell.qml` and five replaced components,
copies the full tree, and prepares `$XDG_DATA_HOME/dms-media-lyrics/current`
(default `~/.local/share/...`). It does not modify installed packages or the
read-only extraction. Hashes are compatibility guards, not full-tree authentication.
Generated generations and preparation workspaces are retained outside Git.
Never relabel a generated tree to bypass the version check.

Configure your session to launch `dms-with-lyrics run` in place of `dms run`;
retain any existing arguments. Do not run a second DMS instance/service.
The launcher uses the prepared tree only for the matching `dms version`, otherwise
stock DMS. Session configuration and any restart remain manual, while unlocked.

## Enable, use, update

With DMS running:

```sh
dms ipc call plugin-scan scan
dms ipc call plugins enable lyrics
dms ipc call plugins enable dankTodo
```

Wait for scanning to finish before enabling. In Settings → DankBar, add **Dank Todo**
to a bar section. Do not add the lyrics daemon as a bar widget. Preferences stay
in DMS. Todo now requires a private Linear API key file; see its
[setup instructions](plugins/dankTodo/README.md). It no longer reads local TODO
files or migrates them. Task data stays in Linear.

Update and review this Git checkout, run offline checks, then reload explicitly:

```sh
dms ipc call plugins reload lyrics
dms ipc call plugins reload dankTodo
```

If imported JavaScript remains cached, restart DMS manually while unlocked.
Overlay changes require re-preparation from pristine source and a manual session
restart through the launcher. Do **not** run registry `dms plugins install`,
`update`, or `restore` for these maintained targets: IDs `lyrics` and `dankTodo`
are preserved, but this checkout, not the registry, owns their sources.
Old lockfile entries are not rewritten by the installer.

## Verification

`sh tests/check-source.sh` runs manifest/inventory and isolated safe-installer
checks, lyrics JavaScript tests, headless Qt 6 QML fixtures, overlay preparation,
Todo mocked GraphQL and QML regressions, and launcher fallback tests. All are offline: no real provider requests, model
calls, desktop changes, or notification sends. Node or Qt 6 tests explicitly skip
when their tools are absent. Python fixtures and QML workspaces are retained under
`~/.local/state/agents/tmp`. These tests do not establish Todo runtime reliability
or constitute a full live-session test.
