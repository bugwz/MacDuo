import AppKit

@main
struct GenerateIcon {
    static func main() throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let iconset = directory.appendingPathComponent("MacDuo.iconset")
        try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
        for size in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let pixels = size * scale
                let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
                let flip = NSAffineTransform()
                flip.translateX(by: 0, yBy: CGFloat(pixels))
                flip.scaleX(by: 1, yBy: -1)
                flip.concat()
                BrandIcon.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels), appIcon: true)
                NSGraphicsContext.restoreGraphicsState()
                let data = bitmap.representation(using: .png, properties: [:])!
                let suffix = scale == 2 ? "@2x" : ""
                try data.write(to: iconset.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
                if pixels == 1024 { try data.write(to: directory.appendingPathComponent("MacDuo.png")) }
            }
        }
        var paths = ""
        for path in BrandIcon.outlines() {
            var d = ""
            let points = UnsafeMutablePointer<NSPoint>.allocate(capacity: 3)
            defer { points.deallocate() }
            for index in 0..<path.elementCount {
                switch path.element(at: index, associatedPoints: points) {
                case .moveTo: d += "M\(points[0].x) \(points[0].y) "
                case .lineTo: d += "L\(points[0].x) \(points[0].y) "
                case .curveTo: d += "C\(points[0].x) \(points[0].y) \(points[1].x) \(points[1].y) \(points[2].x) \(points[2].y) "
                case .closePath: d += "Z "
                default: fatalError("Unsupported vector element")
                }
            }
            paths += "  <path d=\"\(d)\"/>\n"
        }
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" fill="none">
          <title>MacDuo — folding screen and base</title>
          <g stroke="#212B3B" stroke-width="48" stroke-linejoin="round">
        \(paths)  </g>
        </svg>
        """
        try svg.write(to: directory.appendingPathComponent("MacDuo.svg"), atomically: true, encoding: .utf8)
    }
}
