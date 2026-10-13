# Source provenance and licenses

The source migration retained the revisions below. Subsequent Todo changes are
local maintenance, not an upstream version update.

| Source | Revision | Imported material |
| --- | --- | --- |
| [oai404iao/dotfiles](https://github.com/oai404iao/dotfiles) | `03809286da86e12ef7b72af40c17b0e2c9bb6cc1` | Maintained lyrics source, overlay, preparation helper, launcher, lyrics/overlay tests and QML fixtures |
| [Gm-aaa/dms-lyrics](https://github.com/Gm-aaa/dms-lyrics) | `2cea21b36a18ca83a930550e067088856f5d8863` (`0.3.0`) | Base of the locally maintained lyrics daemon (`0.4.0-local.1`); MIT, gmaaa |
| [deepu105/dms-dank-todo](https://github.com/deepu105/dms-dank-todo) | `ff1b82c3061fce3c32c8f65792fa81b928ab35d1` (`1.2.0`) | Both QML files, manifest, README, screenshot and MIT license copied unchanged; no nested Git metadata or upstream agent instructions |
| [AvengeMedia/DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) | v1.6.2 `2db7646fe3ab47fddfdb8723f2da07d61a0d47ac`; v1.6.3 `4a87e8227daf0840b3376fd5e7f891f5900165a6` | Base of the five maintained native media/dropdown QML components; MIT, Avenge Media LLC |

The original per-component LICENSE files are preserved byte-for-byte. The root
LICENSE covers original tooling/docs/tests and does not replace upstream notices.
Migrated tests only change repository paths and omit chezmoi apply-hook checks;
those remain in the dotfiles repository. Original source bytes of plugin files,
overlay components, preparation helper, launcher and fixtures were preserved
at migration. Todo `2.0.0-local.1` is a local rewrite using Linear's GraphQL API,
with a shared daemon, DMS translations, native workflows and sub-issues.
It replaces the earlier local `1.3.0-local.1` enhancements and retains the upstream
license, ID and original author attribution. Its old screenshot is historical,
not a representation of the Linear rewrite.

The supported DMS releases have identical `shell.qml` and the five replaced
component hashes. Full input trees must nevertheless come from the installed
release, preserving all other upstream fixes. Pinned hashes are in
`scripts/prepare-dms-media-lyrics.py`. New DMS versions require a new compatibility
review, not a relaxed version guard.

Use the root README for installation and reviewed Git updates, and the Todo
README for API key setup and upgrade behavior.
