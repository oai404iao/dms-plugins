import importlib.util
import os
from pathlib import Path
import sys
import tempfile

sys.dont_write_bytecode = True
repo = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("installer", repo / "scripts/install.py")
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)
scratch = Path.home() / ".local/state/agents/tmp"
scratch.mkdir(parents=True, exist_ok=True)
task = Path(tempfile.mkdtemp(prefix="check-dms-install.", dir=scratch))
home = task / "home"
config = task / "config"
plugins = config / "DankMaterialShell/plugins"
plugins.mkdir(parents=True)
(plugins / "lyrics").mkdir()
(plugins / "lyrics/keep").write_text("old source")
external = task / "external"
external.mkdir()
(external / "keep").write_text("external source")
(plugins / "dankTodo").symlink_to(external, target_is_directory=True)
(home / ".local/bin").mkdir(parents=True)
(home / ".local/bin/dms-with-lyrics").write_text("old launcher")
(config / "DankMaterialShell/plugin_settings.json").write_text('{"unrelated":true}')
(config / "dank-todo").mkdir()
(config / "dank-todo/todos.json").write_text('{"todos":[]}')
installer.install(home, config, dry_run=True)
assert (plugins / "lyrics/keep").read_text() == "old source"
assert not (home / ".local/state").exists()
backup = installer.install(home, config)
assert backup.stat().st_mode & 0o777 == 0o700
assert (backup / "0-lyrics/keep").read_text() == "old source"
assert (backup / "1-dankTodo").is_symlink()
assert (backup / "1-dankTodo").resolve() == external
assert (backup / "2-dms-with-lyrics").read_text() == "old launcher"
assert (external / "keep").read_text() == "external source"
assert (plugins / "lyrics").resolve() == repo / "plugins/lyrics"
assert (plugins / "dankTodo").resolve() == repo / "plugins/dankTodo"
assert (home / ".local/bin/dms-with-lyrics").resolve() == repo / "bin/dms-with-lyrics"
assert installer.install(home, config) is None
assert len(list((home / ".local/state/agents/tmp").iterdir())) == 1
assert (config / "DankMaterialShell/plugin_settings.json").read_text() == '{"unrelated":true}'
assert (config / "dank-todo/todos.json").read_text() == '{"todos":[]}'


def rejected(home, config):
    try:
        installer.install(home, config)
    except ValueError:
        return
    raise AssertionError("Unsafe destination accepted")


rejected(Path("relative"), config)
rejected(home, Path("relative"))
rejected(Path("/"), config)
rejected(home, repo)
for index, link_target in enumerate((repo, repo.parent, repo / "plugins/dankTodo")):
    blocked = task / f"blocked-{index}"
    directory = blocked / "DankMaterialShell/plugins"
    directory.mkdir(parents=True)
    (directory / "lyrics").symlink_to(link_target, target_is_directory=True)
    rejected(home, blocked)
    assert (directory / "lyrics").is_symlink()
    assert not os.path.lexists(directory / "dankTodo")
parent_config = task / "parent-config"
(parent_config / "DankMaterialShell").mkdir(parents=True)
(parent_config / "DankMaterialShell/plugins").symlink_to(repo / "plugins")
rejected(home, parent_config)
file_config = task / "file-config"
file_config.mkdir()
(file_config / "DankMaterialShell").write_text("not a directory")
rejected(home, file_config)
broken_config = task / "broken-config"
(broken_config / "DankMaterialShell/plugins").mkdir(parents=True)
(broken_config / "DankMaterialShell/plugins/lyrics").symlink_to(task / "missing")
broken_backup = installer.install(task / "broken-home", broken_config)
assert (broken_backup / "0-lyrics").is_symlink()
assert not (broken_backup / "0-lyrics").exists()
print(f"Installer checks passed (retained fixtures: {task})")
