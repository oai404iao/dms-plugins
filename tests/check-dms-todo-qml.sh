#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
runner=/usr/lib/qt6/bin/qmltestrunner
if [ ! -x "$runner" ]; then
    printf '%s\n' "DMS todo QML checks skipped: Qt 6 test runner unavailable"
    exit 0
fi

umask 077
scratch_root="$HOME/.local/state/agents/tmp"
mkdir -p -- "$scratch_root"
task_dir=$(mktemp -d "$scratch_root/check-dms-todo-qml.XXXXXXXX")
cp -R -- "$repo_dir/tests/fixtures/dms-todo-qml/." "$task_dir/"
mkdir -p -- "$task_dir/plugin" "$task_dir/home" "$task_dir/run"
cp -- "$repo_dir/plugins/dankTodo/DankTodoWidget.qml" \
    "$repo_dir/plugins/dankTodo/DankTodoSettings.qml" \
    "$repo_dir/plugins/dankTodo/LinearService.qml" "$task_dir/plugin/"
cp -- "$repo_dir/plugins/dankTodo/LinearApi.js" "$task_dir/plugin/RealLinearApi.js"
cp -- "$task_dir/MockLinearApi.js" "$task_dir/plugin/LinearApi.js"
cp -R -- "$repo_dir/plugins/dankTodo/translations" "$task_dir/plugin/"

if ! env -i PATH=/usr/bin:/bin HOME="$task_dir/home" \
    XDG_RUNTIME_DIR="$task_dir/run" XDG_CONFIG_HOME="$task_dir/home/.config" \
    XDG_DATA_HOME="$task_dir/home/.local/share" XDG_CACHE_HOME="$task_dir/home/.cache" \
    XDG_STATE_HOME="$task_dir/home/.local/state" TMPDIR="$task_dir" \
    QT_QPA_PLATFORM=offscreen QML_XHR_ALLOW_FILE_READ=1 LC_ALL=C.UTF-8 TZ=UTC \
    "$runner" -import "$task_dir/imports" -input "$task_dir/tst_todo.qml" \
    >"$task_dir/result.log" 2>&1; then
    tail -n 200 "$task_dir/result.log"
    exit 1
fi
tail -n 200 "$task_dir/result.log"
# QtTest does not fail a test merely because a delegate binding emits a warning.
if grep -E 'ReferenceError|TypeError|Unable to assign|Cannot assign|Binding loop|Cannot anchor|is not a function' "$task_dir/result.log"; then
    printf '%s\n' "DMS todo QML checks failed: runtime QML errors"
    exit 1
fi
printf '%s\n' "DMS todo QML checks passed (retained fixtures: $task_dir)"
