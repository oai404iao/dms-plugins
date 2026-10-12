#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
runner=/usr/lib/qt6/bin/qmltestrunner
if [ ! -x "$runner" ]; then
    printf '%s\n' "DMS lyrics QML checks skipped: Qt 6 test runner unavailable"
    exit 0
fi

umask 077
scratch_root="$HOME/.local/state/agents/tmp"
mkdir -p -- "$scratch_root"
task_dir=$(mktemp -d "$scratch_root/check-dms-lyrics-qml.XXXXXXXX")
cp -R -- "$repo_dir/tests/fixtures/dms-lyrics-qml/." "$task_dir/"
plugin_dir="$repo_dir/plugins/lyrics"
cp -- "$plugin_dir/LyricsService.qml" "$plugin_dir/LyricsView.qml" "$plugin_dir/LyricsSettings.qml" "$task_dir/plugin/"
cp -- "$plugin_dir/LyricsFetcher.js" "$task_dir/plugin/RealFetcher.js"
mkdir -p -- "$task_dir/overlay"
cp -- "$repo_dir/scripts/dms-media-lyrics/MediaDropdownOverlay.qml" "$repo_dir/scripts/dms-media-lyrics/DankDashPopout.qml" "$task_dir/overlay/"
mkdir -p -- "$task_dir/home" "$task_dir/run"

run_suite() {
    env -i PATH=/usr/bin:/bin HOME="$task_dir/home" \
        XDG_RUNTIME_DIR="$task_dir/run" XDG_CONFIG_HOME="$task_dir/home/.config" \
        XDG_DATA_HOME="$task_dir/home/.local/share" XDG_CACHE_HOME="$task_dir/home/.cache" \
        XDG_STATE_HOME="$task_dir/home/.local/state" TMPDIR="$task_dir" \
        QT_QPA_PLATFORM=offscreen LC_ALL=C.UTF-8 \
        "$runner" -import "$task_dir/imports" -input "$task_dir/$1"
}

run_suite tst_lyrics.qml
run_suite tst_overlay.qml
run_suite tst_dash.qml
printf '%s\n' "DMS lyrics QML checks passed (retained fixtures: $task_dir)"
