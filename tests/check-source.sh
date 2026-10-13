#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
export PYTHONDONTWRITEBYTECODE=1
python3 "$repo_dir/tests/check-install.py"
python3 "$repo_dir/tests/check-inventory.py"
sh "$repo_dir/tests/check-dms-lyrics.sh"
sh "$repo_dir/tests/check-dms-lyrics-qml.sh"
sh "$repo_dir/tests/check-dms-todo.sh"
sh "$repo_dir/tests/check-dms-todo-qml.sh"
sh "$repo_dir/tests/check-dms-media-lyrics.sh"
