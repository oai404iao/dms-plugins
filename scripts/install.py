#!/usr/bin/env python3
"""Link the reviewed local sources; never fetch, enable, or restart DMS."""
import argparse
import os
from pathlib import Path
import tempfile


REPO = Path(__file__).resolve().parents[1]


def protected(path, repo):
    resolved = path.resolve()
    return resolved.is_relative_to(repo) or repo.is_relative_to(resolved)


def install(home, config, *, dry_run=False, repo=REPO):
    home, config, repo = Path(home), Path(config), Path(repo).resolve(strict=True)
    for root in (home, config):
        if not root.is_absolute() or root == Path("/"):
            raise ValueError("HOME and XDG_CONFIG_HOME must be absolute non-root paths")
    scratch = home / ".local/state/agents/tmp"
    plans = [
        (repo / "plugins/lyrics", config / "DankMaterialShell/plugins/lyrics"),
        (repo / "plugins/dankTodo", config / "DankMaterialShell/plugins/dankTodo"),
        (repo / "bin/dms-with-lyrics", home / ".local/bin/dms-with-lyrics"),
    ]
    pending = []
    for source, target in plans:
        source.resolve(strict=True)
        if target.parent.resolve().is_relative_to(repo):
            raise ValueError(f"Destination parent is inside the source repository: {target}")
        if target.is_symlink() and target.resolve() == source:
            print(f"Already linked: {target}")
            continue
        if protected(target, repo):
            raise ValueError(f"Refusing repository-overlapping destination: {target}")
        ancestor = target.parent
        while not ancestor.exists() and not ancestor.is_symlink():
            ancestor = ancestor.parent
        if not ancestor.is_dir():
            raise ValueError(f"Destination parent is not a directory: {ancestor}")
        pending.append((source, target, ancestor))
    if not pending:
        return None
    if protected(scratch, repo):
        raise ValueError("Backup directory overlaps the repository")
    if dry_run:
        for source, target, _ in pending:
            print(f"Would back up if present and link: {target} -> {source}")
        return None
    scratch.mkdir(parents=True, exist_ok=True)
    # Rename-only backups retain directories, symlinks, and Git metadata intact.
    for _, target, ancestor in pending:
        if os.path.lexists(target) and ancestor.stat().st_dev != scratch.stat().st_dev:
            raise ValueError(f"Cannot safely rename backup across filesystems: {target}")
    backup = Path(tempfile.mkdtemp(prefix="dms-plugins-install.", dir=scratch))
    backup.chmod(0o700)
    for index, (source, target, _) in enumerate(pending):
        target.parent.mkdir(parents=True, exist_ok=True)
        if os.path.lexists(target):
            saved = backup / f"{index}-{target.name}"
            target.rename(saved)
            print(f"Backup: {target} -> {saved}")
        target.symlink_to(source, target_is_directory=source.is_dir())
        print(f"Linked: {target} -> {source}")
    print(f"Retained installation workspace: {backup}")
    return backup


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    home = Path.home()
    config = Path(os.environ.get("XDG_CONFIG_HOME") or home / ".config")
    try:
        install(home, config, dry_run=args.dry_run)
    except (OSError, ValueError) as error:
        parser.exit(1, f"Installation stopped: {error}\nExisting backups are retained; no cleanup was attempted.\n")


if __name__ == "__main__":
    main()
