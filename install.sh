#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
if [[ -z "${1:-}" ]]; then
    ./build.sh
elif [[ "$1" != '--no-build' ]]; then
    print -u2 -- 'Usage: ./install.sh [--no-build]'
    exit 2
fi
codesign --verify --deep --strict 'build/Screenshot Shelf.app'
task_destination="$HOME/Applications/Screenshot Shelf.app"
mkdir -p "$HOME/Applications"
if pgrep -x ScreenshotShelf >/dev/null; then
    pkill -x ScreenshotShelf
    for task_attempt in {1..50}; do
        if ! pgrep -x ScreenshotShelf >/dev/null; then break; fi
        sleep 0.1
    done
    if pgrep -x ScreenshotShelf >/dev/null; then
        print -u2 -- 'Screenshot Shelf is still quitting. Close it and rerun install.sh.'
        exit 1
    fi
fi
ditto 'build/Screenshot Shelf.app' "$task_destination"
open -n "$task_destination" --args --enable-login
print -r -- "Installed: $task_destination"
