#!/usr/bin/env python3
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import tempfile

SUPPORTED_VERSIONS = ("v1.6.2", "v1.6.3")
# These reviewed releases have identical shell and overlaid component sources.
BASE_HASHES = {
    "shell.qml": "e35630e0e47c7ce9530c050ddbf22b9637344081b3aa8ae0163cf3c16aa6ccef",
    "Modules/DankDash/MediaPlayerDashChrome.qml": "b9a1916886d5b946d2aeb29d0cfda20783e7874525f6d982aa22b1bc32d10369",
    "Modules/DankBar/Widgets/Media.qml": "11c38b5654106ad86ba25dd8b9a0072d02e9f5cdb3d46fb04286f5f73796e18b",
    "Modules/DankDash/DankDashPopout.qml": "1fcb4ca61284d464263ad461b24f8bf522d7550f4d915ab0ad9208c1f1f46294",
    "Modules/DankDash/MediaPlayerTab.qml": "1cbb6a7f9354535f40ff5f6d286d4bddcacd23a1eceea65346899d6701916664",
    "Modules/DankDash/MediaDropdownOverlay.qml": "e007c71431060aec498f7a121b7f9bef47222ef3f97517d048d26fcfd67b5d97",
}
OVERLAYS = tuple(path for path in BASE_HASHES if path != "shell.qml")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepare(source, data_home, scratch_root):
    source = source.resolve(strict=True)
    version = (source / "VERSION").read_text().strip()
    if version not in SUPPORTED_VERSIONS:
        raise ValueError(
            f"Expected DMS {' or '.join(SUPPORTED_VERSIONS)}; "
            "refusing to reuse this overlay on another version"
        )
    for relative, expected in BASE_HASHES.items():
        if digest(source / relative) != expected:
            raise ValueError(f"Unrecognized DMS source: {relative}")
    if any(path.is_symlink() for path in source.rglob("*")):
        raise ValueError("DMS source must be a complete tree without symlinks")

    runtime = data_home / "dms-media-lyrics"
    current = runtime / "current"
    if current.exists() and not current.is_symlink():
        raise ValueError(f"Refusing to replace non-symlink: {current}")
    overlay = Path(__file__).parent / "dms-media-lyrics"
    scratch_root.mkdir(parents=True, exist_ok=True)
    task = Path(tempfile.mkdtemp(prefix="dms-media-lyrics.", dir=scratch_root))
    staging = task / "shell"
    shutil.copytree(source, staging)
    staging.chmod(0o700)
    for relative in OVERLAYS:
        target = staging / relative
        target.chmod(0o600)
        shutil.copyfile(overlay / target.name, target)
    shutil.copyfile(overlay / "LICENSE", staging / "MEDIA-LYRICS-LICENSE")
    (staging / ".dms-version").write_text(f"dms {version}\n")

    runtime.mkdir(parents=True, exist_ok=True)
    generation = runtime / task.name
    shutil.copytree(staging, generation)
    if current.exists() and not current.is_symlink():
        raise ValueError(f"Refusing to replace non-symlink: {current}")
    link = runtime / f".{task.name}.link"
    link.symlink_to(generation.name, target_is_directory=True)
    os.replace(link, current)
    print(f"Prepared DMS media lyrics: {current}")
    print(f"Retained preparation workspace: {task}")
    return generation


def main():
    parser = argparse.ArgumentParser(description="Prepare an offline, version-checked DMS media lyrics overlay.")
    parser.add_argument(
        "source", type=Path,
        help=f"Pristine extracted DMS {' or '.join(SUPPORTED_VERSIONS)} shell directory",
    )
    args = parser.parse_args()
    home = Path.home()
    data_home = Path(os.environ.get("XDG_DATA_HOME") or home / ".local/share")
    prepare(args.source, data_home, home / ".local/state/agents/tmp")


if __name__ == "__main__":
    main()
