#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if ! command -v node >/dev/null 2>&1; then
    printf '%s\n' "DMS Linear API checks skipped: Node unavailable"
    exit 0
fi
node "$repo_dir/tests/check-dms-todo.mjs"
