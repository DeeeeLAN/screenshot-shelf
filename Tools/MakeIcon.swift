import AppKit

@main
struct MakeIcon {
    static func main() throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for size in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let pixels = size * scale
                let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
                let transform = NSAffineTransform()
                transform.scale(by: CGFloat(pixels) / 512)
                transform.concat()
                let tile = NSBezierPath(roundedRect: NSRect(x: 36, y: 36, width: 440, height: 440), xRadius: 100, yRadius: 100)
                NSGradient(starting: NSColor(calibratedRed: 0.10, green: 0.20, blue: 0.31, alpha: 1), ending: NSColor(calibratedRed: 0.04, green: 0.09, blue: 0.17, alpha: 1))!.draw(in: tile, angle: -80)
                NSColor.white.withAlphaComponent(0.28).setFill()
                NSBezierPath(roundedRect: NSRect(x: 105, y: 199, width: 249, height: 177), xRadius: 24, yRadius: 24).fill()
                NSColor(calibratedWhite: 0.97, alpha: 1).setFill()
                NSBezierPath(roundedRect: NSRect(x: 141, y: 144, width: 264, height: 189), xRadius: 24, yRadius: 24).fill()
                NSColor(calibratedRed: 0.12, green: 0.68, blue: 0.64, alpha: 1).setFill()
                let mountain = NSBezierPath()
                mountain.move(to: NSPoint(x: 164, y: 167))
                mountain.line(to: NSPoint(x: 225, y: 247))
                mountain.line(to: NSPoint(x: 270, y: 196))
                mountain.line(to: NSPoint(x: 311, y: 230))
                mountain.line(to: NSPoint(x: 382, y: 167))
                mountain.close()
                mountain.fill()
                NSColor(calibratedRed: 1, green: 0.73, blue: 0.24, alpha: 1).setFill()
                NSBezierPath(ovalIn: NSRect(x: 319, y: 262, width: 34, height: 34)).fill()
                let arrow = NSBezierPath()
                arrow.move(to: NSPoint(x: 320, y: 183))
                arrow.line(to: NSPoint(x: 338, y: 80))
                arrow.line(to: NSPoint(x: 362, y: 109))
                arrow.line(to: NSPoint(x: 381, y: 77))
                arrow.line(to: NSPoint(x: 401, y: 89))
                arrow.line(to: NSPoint(x: 382, y: 121))
                arrow.line(to: NSPoint(x: 419, y: 127))
                arrow.close()
                NSColor.white.setStroke()
                arrow.lineWidth = 9
                arrow.lineJoinStyle = .round
                arrow.stroke()
                NSColor(calibratedRed: 0.09, green: 0.22, blue: 0.31, alpha: 1).setFill()
                arrow.fill()
                NSGraphicsContext.restoreGraphicsState()
                let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
                try rep.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name))
            }
        }
    }
}
