import json
from pathlib import Path

repo = Path(__file__).resolve().parents[1]
inventories = {
    "lyrics": {
        "LICENSE", "plugin.json", "LyricsFetcher.js", "LyricsView.qml",
        "LyricsService.qml", "LyricsSettings.qml", "translations/zh_CN.json",
    },
    "dankTodo": {
        "LICENSE", "README.md", "screenshot.png", "plugin.json",
        "DankTodoWidget.qml", "DankTodoSettings.qml",
    },
}


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        assert key not in result, f"Duplicate JSON key: {key}"
        result[key] = value
    return result


assert {p.name for p in (repo / "plugins").iterdir()} == set(inventories)
for name, expected in inventories.items():
    directory = repo / "plugins" / name
    assert not any(p.is_symlink() for p in directory.rglob("*"))
    actual = {p.relative_to(directory).as_posix() for p in directory.rglob("*") if p.is_file()}
    assert actual == expected, (name, actual ^ expected)
    manifest = json.loads((directory / "plugin.json").read_text(), object_pairs_hook=unique_object)
    assert manifest["id"] == name
    assert (directory / manifest["component"]).is_file()
    assert (directory / manifest["settings"]).is_file()
    if name == "lyrics":
        assert manifest["type"] == "daemon"
        assert manifest["capabilities"] == []
        assert manifest["component"] == "./LyricsService.qml"
        schema = manifest["settings_schema"]
        assert schema["showLyrics"]["default"] is True
        assert schema["showTranslation"]["default"] is True
        assert schema["translationLanguage"]["default"] == "source"
    else:
        assert manifest["type"] == "widget"
        assert manifest["capabilities"] == ["dankbar-widget"]
        assert manifest["version"] == "1.2.0"
for path in (repo / "plugins").rglob("*.json"):
    json.loads(path.read_text(), object_pairs_hook=unique_object)
print("Plugin manifest and exact source inventory checks passed")
