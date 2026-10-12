import hashlib
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
repo = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("prepare", repo / "scripts/prepare-dms-media-lyrics.py")
prepare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare)

scratch_root = Path.home() / ".local/state/agents/tmp"
scratch_root.mkdir(parents=True, exist_ok=True)
task = Path(tempfile.mkdtemp(prefix="check-dms-media-lyrics.", dir=scratch_root))
source = task / "source"
data = task / "data"
for relative in prepare.OVERLAYS:
    target = source / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(f"approved {target.name} fixture\n")
(source / "shell.qml").write_text("approved shell fixture\n")
(source / "VERSION").write_text("v1.6.2\n")
(source / "untouched.qml").write_text("keep this file\n")
originals = {p.relative_to(source): p.read_bytes() for p in source.rglob("*") if p.is_file()}

assert prepare.SUPPORTED_VERSIONS == ("v1.6.2", "v1.6.3")
assert set(prepare.BASE_HASHES) == {"shell.qml", *prepare.OVERLAYS}
assert all(len(value) == 64 for value in prepare.BASE_HASHES.values())
prepare.BASE_HASHES = {
    relative: hashlib.sha256((source / relative).read_bytes()).hexdigest()
    for relative in prepare.BASE_HASHES
}
current = data / "dms-media-lyrics/current"
generations = {}
for version in prepare.SUPPORTED_VERSIONS:
    (source / "VERSION").write_text(f"{version}\n")
    originals[Path("VERSION")] = (source / "VERSION").read_bytes()
    generation = prepare.prepare(source, data, task / "builds")
    generations[version] = generation
    assert current.resolve() == generation
    for relative in prepare.OVERLAYS:
        assert (generation / relative).read_bytes() == (
            repo / "scripts/dms-media-lyrics" / Path(relative).name
        ).read_bytes()
    assert (generation / "untouched.qml").read_bytes() == (source / "untouched.qml").read_bytes()
    assert (generation / "VERSION").read_text() == f"{version}\n"
    assert (generation / ".dms-version").read_text() == f"dms {version}\n"
    assert (generation / "MEDIA-LYRICS-LICENSE").read_bytes() == (
        repo / "scripts/dms-media-lyrics/LICENSE"
    ).read_bytes()
    assert {p.relative_to(source): p.read_bytes() for p in source.rglob("*") if p.is_file()} == originals


def expect_rejected():
    old_target = current.resolve()
    try:
        prepare.prepare(source, data, task / "builds")
    except ValueError:
        pass
    else:
        raise AssertionError("Expected source validation failure")
    assert current.resolve() == old_target


for version in ("v1.6.4", "v1.7.0"):
    (source / "VERSION").write_text(f"{version}\n")
    expect_rejected()
for version in prepare.SUPPORTED_VERSIONS:
    (source / "VERSION").write_text(f"{version}\n")
    for relative in prepare.BASE_HASHES:
        (source / relative).write_text("unexpected core changes\n")
        expect_rejected()
        (source / relative).write_bytes(originals[Path(relative)])
link = source / "external.qml"
link.symlink_to(task / "outside")
expect_rejected()
link.unlink()
next_generation = prepare.prepare(source, data, task / "builds")
assert next_generation not in generations.values()
assert current.resolve() == next_generation
for version, generation in generations.items():
    assert generation.is_dir()
    assert (generation / ".dms-version").read_text() == f"dms {version}\n"
assert len(list((task / "builds").glob("*/shell/shell.qml"))) == 3

blocked_data = task / "blocked"
(blocked_data / "dms-media-lyrics/current").mkdir(parents=True)
try:
    prepare.prepare(source, blocked_data, task / "blocked-builds")
except ValueError:
    pass
else:
    raise AssertionError("Must not replace an existing directory")
assert not (task / "blocked-builds").exists()

bin_dir = task / "bin"
bin_dir.mkdir()
fake_dms = bin_dir / "dms"
fake_dms.write_text(
    '#!/bin/sh\n'
    'if [ "$1" = version ]; then\n'
    '    printf "%s\\n" "$FAKE_DMS_VERSION"\n'
    'else\n'
    '    printf "%s\\n" "${DMS_SHELL_DIR-unset}" "$@"\n'
    'fi\n'
)
fake_dms.chmod(0o700)
env = {
    **os.environ, "HOME": str(task / "home"), "XDG_DATA_HOME": str(data),
    "PATH": f"{bin_dir}:/usr/bin:/bin", "FAKE_DMS_VERSION": "dms v1.6.2",
    "DMS_SHELL_DIR": "/must-not-leak",
}
launcher = repo / "bin/dms-with-lyrics"


def launch():
    return subprocess.run(
        [str(launcher), "run", "-d"], env=env, check=True, capture_output=True, text=True
    )


for version, generation in generations.items():
    current.unlink()
    current.symlink_to(generation)
    for installed in (*prepare.SUPPORTED_VERSIONS, "v1.6.4", "v1.7.0"):
        env["FAKE_DMS_VERSION"] = f"dms {installed}"
        result = launch()
        if installed == version:
            assert result.stdout.splitlines() == [str(current), "run", "-d"]
            assert not result.stderr
        else:
            assert result.stdout.splitlines() == ["unset", "run", "-d"]
            assert "version mismatch" in result.stderr
env["XDG_DATA_HOME"] = str(task / "missing-data")
assert launch().stdout.splitlines() == ["unset", "run", "-d"]
media = (repo / "scripts/dms-media-lyrics/Media.qml").read_text()
assert media.index("id: mediaInfo") < media.index("id: mediaControls") < media.index("id: textContainer")
assert 'PluginService.pluginDaemonInstances["lyrics"]' in media
chrome = (repo / "scripts/dms-media-lyrics/MediaPlayerDashChrome.qml").read_text()
assert 'PluginService.pluginDaemonInstances["lyrics"]' in chrome
assert "BarWidgetService.getWidget" not in chrome
assert "id: lyricsSettingsButton" in chrome
assert "settingsView" not in chrome
assert "lyricsSettingsOpen" not in chrome
assert "player.triggerLyricsDropdown()" in chrome
overlay = (repo / "scripts/dms-media-lyrics/MediaDropdownOverlay.qml").read_text()
assert "root.lyricsService?.settingsView" in overlay
assert "return lyricsSettingsPanel;" in overlay
assert "root.clampX(root.isRightEdge ? root.anchorPos.x : root.anchorPos.x - width, width)" in overlay
tab = (repo / "scripts/dms-media-lyrics/MediaPlayerTab.qml").read_text()
assert "dropdownAnchor(chromeLoader.item.lyricsSettingsButton)" in tab
assert "lyricsExpanded = false;" in tab
dash = (repo / "scripts/dms-media-lyrics/DankDashPopout.qml").read_text()
assert "onShowLyricsDropdown:" in dash
assert "availableBounds: Qt.rect(0, 0, width, height)" in dash
print(f"DMS media overlay offline checks passed (retained fixtures: {task})")
