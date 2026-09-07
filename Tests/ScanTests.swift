import AppKit

@main
struct ScanTests {
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("ScreenshotShelf-tests-" + UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            guard condition() else { fatalError(message) }
            print("PASS: " + message)
        }
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 80, pixelsHigh: 40, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let png = bitmap.representation(using: .png, properties: [:])!
        func write(_ name: String, age: TimeInterval) throws -> URL {
            let url = root.appendingPathComponent(name)
            try png.write(to: url)
            try fm.setAttributes([.creationDate: Date(timeIntervalSince1970: 1_700_000_000 + age)], ofItemAtPath: url.path)
            return url
        }
        let old = try write("Screenshot old.png", age: 0)
        let newest = try write("Screenshot newest.png", age: 100)
        _ = try write("Screen Shot middle.png", age: 50)
        _ = try write("holiday photo.png", age: 200)
        try fm.createDirectory(at: root.appendingPathComponent("Screenshot directory.png"), withIntermediateDirectories: true)
        let scan = ScreenshotStore.scan(folder: root)
        check(scan.error == nil && scan.screenshots.count == 3, "Only screenshot image files are included")
        check(scan.screenshots.first?.url.lastPathComponent == newest.lastPathComponent && scan.screenshots.last?.url.lastPathComponent == old.lastPathComponent, "Newest captures sort first")
        check(scan.screenshots.allSatisfy { $0.thumbnail != nil && $0.dimensions == "80 × 40" }, "Thumbnails and image dimensions load")
        check(ScreenshotStore.scan(folder: root, limit: 2).screenshots.count == 2, "Result limit is respected")
        let cached = ScreenshotStore.scan(folder: root)
        check(cached.screenshots.first?.revision == scan.screenshots.first?.revision, "Unchanged files retain their revision")
        try fm.setAttributes([.modificationDate: Date()], ofItemAtPath: newest.path)
        check(ScreenshotStore.scan(folder: root).screenshots.first?.revision != scan.screenshots.first?.revision, "Edited files invalidate their cached preview")
        let invalid = root.appendingPathComponent("Screenshot incomplete.png")
        try Data().write(to: invalid)
        check(ScreenshotStore.scan(folder: root).screenshots.count == 4, "An incomplete screenshot does not break the shelf")
        check(ScreenshotStore.scan(folder: root.appendingPathComponent("missing")).error != nil, "An inaccessible folder produces a visible error")
        let empty = root.appendingPathComponent("empty")
        try fm.createDirectory(at: empty, withIntermediateDirectories: true)
        let emptyScan = ScreenshotStore.scan(folder: empty)
        check(emptyScan.error == nil && emptyScan.screenshots.isEmpty, "Empty folders are handled")
    }
}
