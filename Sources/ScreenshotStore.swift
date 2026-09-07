import AppKit
import ImageIO

struct Screenshot {
    let url: URL
    let date: Date
    let thumbnail: NSImage?
    let dimensions: String
    let revision: String
}

struct ScreenshotScan {
    let folder: URL
    let screenshots: [Screenshot]
    let error: String?
}

enum ScreenshotStore {
    private final class Preview: NSObject {
        let image: NSImage?
        let dimensions: String
        init(image: NSImage?, dimensions: String) { self.image = image; self.dimensions = dimensions }
    }
    private static let previews: NSCache<NSString, Preview> = {
        let cache = NSCache<NSString, Preview>()
        cache.countLimit = 60
        return cache
    }()
    static var folder: URL {
        let custom = UserDefaults.standard.string(forKey: "screenshotFolder")
        let system = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location")
        let path = custom ?? system ?? (NSHomeDirectory() + "/Desktop")
        return URL(fileURLWithPath: (path as NSString).expandingTildeInPath).standardizedFileURL
    }

    static func isScreenshot(_ url: URL) -> Bool {
        guard ["png", "jpg", "jpeg", "heic", "tif", "tiff", "webp", "pdf"].contains(url.pathExtension.lowercased()) else { return false }
        if let item = NSMetadataItem(url: url), (item.value(forAttribute: "kMDItemIsScreenCapture") as? Bool) == true { return true }
        // Filename fallback also works on Macs with Spotlight indexing disabled.
        let name = url.deletingPathExtension().lastPathComponent.lowercased()
        let systemName = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "name")?.lowercased()
        let prefixes = ["screenshot", "screen shot", "screen capture", "bildschirmfoto", "capture d’écran", "capture d'écran", "capture d'ecran", "captura de pantalla", "captura de tela", "schermata", "schermafbeelding", "スクリーンショット", "屏幕快照", "截屏", "스크린샷"]
        return prefixes.contains(where: name.hasPrefix) || (systemName.map { !$0.isEmpty && name.hasPrefix($0) } ?? false)
    }

    static func scan(folder: URL = folder, limit: Int = 30) -> ScreenshotScan {
        do {
            let keys: Set<URLResourceKey> = [.creationDateKey, .contentModificationDateKey, .isRegularFileKey, .fileSizeKey]
            let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles])
            let candidates: [(URL, Date)] = files.compactMap { url in
                guard let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true, isScreenshot(url) else { return nil }
                return (url, values.creationDate ?? values.contentModificationDate ?? .distantPast)
            }.sorted { $0.1 == $1.1 ? $0.0.lastPathComponent > $1.0.lastPathComponent : $0.1 > $1.1 }
            let shots = candidates.prefix(limit).map { url, date -> Screenshot in
                let values = try? url.resourceValues(forKeys: keys)
                let revision = "\(url.path)|\(values?.contentModificationDate?.timeIntervalSince1970 ?? 0)|\(values?.fileSize ?? 0)"
                if let cached = previews.object(forKey: revision as NSString) {
                    return Screenshot(url: url, date: date, thumbnail: cached.image, dimensions: cached.dimensions, revision: revision)
                }
                var thumbnail: NSImage?
                var dimensions = "Image"
                if let source = CGImageSourceCreateWithURL(url as CFURL, nil) {
                    let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 480, kCGImageSourceCreateThumbnailWithTransform: true]
                    if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
                        thumbnail = NSImage(cgImage: cgImage, size: .zero)
                    }
                    if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                       let width = properties[kCGImagePropertyPixelWidth] as? Int,
                       let height = properties[kCGImagePropertyPixelHeight] as? Int {
                        dimensions = "\(width) × \(height)"
                    }
                } else if url.pathExtension.lowercased() == "pdf" {
                    thumbnail = NSImage(contentsOf: url)
                    dimensions = "PDF"
                }
                if thumbnail != nil { previews.setObject(Preview(image: thumbnail, dimensions: dimensions), forKey: revision as NSString) }
                return Screenshot(url: url, date: date, thumbnail: thumbnail, dimensions: dimensions, revision: revision)
            }
            return ScreenshotScan(folder: folder, screenshots: shots, error: nil)
        } catch {
            return ScreenshotScan(folder: folder, screenshots: [], error: error.localizedDescription)
        }
    }
}
