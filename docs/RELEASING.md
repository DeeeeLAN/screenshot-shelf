# Releasing Screenshot Shelf

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in `Info.plist`, and add the release to `CHANGELOG.md`.
2. Run `./test.sh` and `./package.sh` on macOS. The latter builds both architectures, creates the icon, verifies the signature, and produces a DMG, ZIP, and SHA-256 checksums in `dist/`.
3. Verify the DMG with `hdiutil verify dist/Screenshot-Shelf-VERSION-universal.dmg`, and smoke-test the app on a Mac. Hold ⌘⇧S and release each key independently. Start a drag, release the keys, and finish the drop.
4. Commit the source, tag it `vVERSION`, and push the commit and tag.
5. Create a GitHub release for that tag and attach only the DMG, ZIP, and checksum file. Do not attach `build/`, which may contain local diagnostics and test fixtures.

CI runs the automated tests and universal build for pushes and pull requests. The release files are built locally; CI does not publish releases automatically.

## Apple signing and notarization

The default package is ad-hoc signed and must be described as **not notarized** in release notes. Do not disable Gatekeeper or remove quarantine attributes in installation scripts.

To distribute with an Apple Developer ID certificate, set `SCREENSHOT_SHELF_SIGN_IDENTITY` to the certificate's name before running `./package.sh`. The build enables hardened runtime and timestamps for that identity. Developer ID signing alone does not notarize the app. Follow Apple's notarization workflow to submit an archive, staple an accepted ticket, and regenerate packages and checksums. Do not commit certificates or credentials to this repository.
