#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
task_app="$PWD/build/Screenshot Shelf.app"
task_architectures=("$(uname -m)")
if [[ "${1:-}" == '--universal' ]]; then
    task_architectures=(arm64 x86_64)
elif [[ -n "${1:-}" ]]; then
    print -u2 -- 'Usage: ./build.sh [--universal]'
    exit 2
fi
mkdir -p "$task_app/Contents/MacOS" "$task_app/Contents/Resources" build/bin
task_binaries=()
for task_arch in "${task_architectures[@]}"; do
    task_binary="$PWD/build/bin/ScreenshotShelf-$task_arch"
    xcrun swiftc -swift-version 5 -O -target "$task_arch-apple-macosx13.0" -framework AppKit -framework Carbon -framework ServiceManagement -framework ImageIO Sources/*.swift -o "$task_binary"
    task_binaries+=("$task_binary")
done
xcrun lipo -create "${task_binaries[@]}" -output "$task_app/Contents/MacOS/ScreenshotShelf"
xcrun swiftc -swift-version 5 -parse-as-library Tools/MakeIcon.swift -o build/make-icon
build/make-icon build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$task_app/Contents/Resources/AppIcon.icns"
cp Info.plist "$task_app/Contents/Info.plist"
task_identity="${SCREENSHOT_SHELF_SIGN_IDENTITY:--}"
if [[ "$task_identity" == '-' ]]; then
    codesign --force --sign - "$task_app"
else
    codesign --force --options runtime --timestamp --sign "$task_identity" "$task_app"
fi
codesign --verify --deep --strict "$task_app"
print -r -- "Built: $task_app"
