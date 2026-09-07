#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
task_app="$PWD/build/DragProbe.app"
mkdir -p "$task_app/Contents/MacOS"
xcrun swiftc -swift-version 5 Sources/ScreenshotStore.swift Sources/ShelfWindow.swift Tests/DragProbe.swift -o "$task_app/Contents/MacOS/DragProbe"
cat > "$task_app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>DragProbe</string>
<key>CFBundleIdentifier</key><string>local.kanishk.ScreenshotShelf.DragProbe</string>
<key>CFBundleName</key><string>DragProbe</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST
codesign --force --sign - "$task_app"
print -r -- "Open $task_app and drag the fixture into the drop target."
print -r -- 'All four values in build/drag-result.json should be true.'
