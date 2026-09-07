#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p build
xcrun swiftc Sources/ScreenshotStore.swift Tests/ScanTests.swift -o build/scan-tests
build/scan-tests
xcrun swiftc Sources/ScreenshotStore.swift Sources/ShelfWindow.swift Sources/HoldGesture.swift Tests/HoldGestureTests.swift -o build/hold-tests
build/hold-tests
