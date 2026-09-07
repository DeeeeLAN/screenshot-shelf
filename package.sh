#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
./build.sh --universal
task_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)
task_name="Screenshot-Shelf-$task_version-universal"
task_app="$PWD/build/Screenshot Shelf.app"
mkdir -p dist
ditto -c -k --sequesterRsrc --keepParent "$task_app" "dist/$task_name.zip"
task_stage=$(mktemp -d "$PWD/build/dmg-stage.XXXXXX")
trap 'rm -rf -- "$task_stage"' EXIT
ditto "$task_app" "$task_stage/Screenshot Shelf.app"
ln -s /Applications "$task_stage/Applications"
cp docs/INSTALL.txt "$task_stage/Read Me.txt"
cp LICENSE "$task_stage/LICENSE.txt"
hdiutil create -ov -volname 'Screenshot Shelf' -srcfolder "$task_stage" -format UDZO "dist/$task_name.dmg"
cd dist
shasum -a 256 "$task_name.zip" "$task_name.dmg" > SHA256SUMS.txt
print -r -- "Packaged version $task_version for Apple silicon and Intel."
