import AppKit
import QuartzCore
import CoreImage
import SwiftUI
import FoldCore

final class FoldView: NSView {
    private let display = CALayer()
    private let renderQueue = DispatchQueue(label: "dev.macduo.fold", qos: .userInitiated)
    private let renderer = FoldRenderer()
    private var latestImage: CGImage?
    private var rendering = false
    private var revision: UInt64 = 0
    var onDismiss: (() -> Void)?
    var progress: Double = 0 {
        didSet {
            guard progress != oldValue else { return }
            revision &+= 1
            requestRender()
        }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.masksToBounds = true
        display.contentsGravity = .resize
        layer?.addSublayer(display)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setImage(_ image: CGImage) {
        guard latestImage !== image else { return }
        latestImage = image
        revision &+= 1
        requestRender()
    }

    private func present(_ image: CGImage) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        display.contents = image
        CATransaction.commit()
    }

    private func requestRender() {
        guard let image = latestImage else { return }
        let pose = FoldPose(progress: progress)
        if pose.intensity < 0.001 {
            present(image)
            return
        }
        guard !rendering else { return }
        rendering = true
        let requestedRevision = revision
        let renderer = renderer
        // One render in flight. New frames and angles replace pending work.
        renderQueue.async { [weak self] in
            let result = renderer.render(image, progress: pose.progress)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.rendering = false
                // Never flash an obsolete pose after returning to the reference.
                if FoldPose(progress: self.progress).intensity >= 0.001 {
                    self.present(result ?? image)
                }
                if self.revision != requestedRevision { self.requestRender() }
            }
        }
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        display.frame = bounds
        CATransaction.commit()
    }

    override func mouseDown(with event: NSEvent) { onDismiss?() }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onDismiss?() } else { super.keyDown(with: event) }
    }
    override var acceptsFirstResponder: Bool { true }
}

struct FoldPreview: NSViewRepresentable {
    let progress: Double
    let image: CGImage
    func makeNSView(context: Context) -> FoldView {
        let view = FoldView(frame: .zero)
        view.setImage(image)
        return view
    }
    func updateNSView(_ view: FoldView, context: Context) {
        view.setImage(image)
        view.progress = progress
    }
}

func makePreviewImage() -> CGImage {
    let image = NSImage(size: NSSize(width: 960, height: 600))
    image.lockFocus()
    NSGradient(colors: [NSColor(red: 0.12, green: 0.21, blue: 0.39, alpha: 1),
                        NSColor(red: 0.36, green: 0.62, blue: 0.72, alpha: 1)])!
        .draw(in: NSRect(x: 0, y: 0, width: 960, height: 600), angle: 30)
    NSColor.white.withAlphaComponent(0.08).setFill()
    for x in stride(from: 0, to: 960, by: 60) {
        NSBezierPath(rect: NSRect(x: x, y: 0, width: 1, height: 600)).fill()
    }
    for y in stride(from: 0, to: 600, by: 60) {
        NSBezierPath(rect: NSRect(x: 0, y: y, width: 960, height: 1)).fill()
    }
    NSColor.white.withAlphaComponent(0.9).setFill()
    NSBezierPath(roundedRect: NSRect(x: 240, y: 100, width: 480, height: 400), xRadius: 18, yRadius: 18).fill()
    let title: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 44, weight: .semibold), .foregroundColor: NSColor.darkGray]
    ("MacDuo" as NSString).draw(at: NSPoint(x: 285, y: 370), withAttributes: title)
    let detail: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 22), .foregroundColor: NSColor.darkGray]
    ("跟随开合 · 停留此刻" as NSString).draw(at: NSPoint(x: 285, y: 330), withAttributes: detail)
    NSColor.systemTeal.withAlphaComponent(0.3).setFill()
    for y in [170, 215, 260] {
        NSBezierPath(roundedRect: NSRect(x: 285, y: y, width: y == 170 ? 240 : 350, height: 16), xRadius: 8, yRadius: 8).fill()
    }
    image.unlockFocus()
    return image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
}
