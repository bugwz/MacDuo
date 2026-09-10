// Compile alongside FoldView.swift and FoldRenderer.swift, linking FoldCore.
// This exercises the real Metal kernel, which requires access to a GPU.
import AppKit
import Foundation

@main
struct RenderFoldPreview {
    static func main() throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".build/fold-preview")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let renderer = FoldRenderer()
        let source = makePreviewImage()
        for (name, progress) in [("flat", 0.0), ("closing", 0.55), ("closed", 1.0), ("opening", -0.7)] {
            guard let image = renderer.render(source, progress: progress),
                  let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
                throw NSError(domain: "MacDuo.RenderCheck", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Rendering failed at \(name)"])
            }
            try data.write(to: directory.appendingPathComponent("\(name).png"))
            print("Rendered \(name)")
        }
    }
}
