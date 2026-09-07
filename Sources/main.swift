import AppKit

if CommandLine.arguments.contains("--diagnose") {
    let scan = ScreenshotStore.scan()
    let output: [String: Any] = ["folder": scan.folder.path, "count": scan.screenshots.count, "error": scan.error as Any? ?? NSNull(), "screenshots": scan.screenshots.map { ["name": $0.url.lastPathComponent, "dimensions": $0.dimensions, "thumbnail": $0.thumbnail != nil] }]
    if let data = try? JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]), let text = String(data: data, encoding: .utf8) { print(text) }
    exit(scan.error == nil ? 0 : 1)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
