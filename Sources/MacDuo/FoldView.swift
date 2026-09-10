import AppKit
import QuartzCore
import CoreImage
import SwiftUI

final class FoldView: NSView {
    private let backdrop = CALayer()
    private let backdropTint = CALayer()
    private static let blurQueue = DispatchQueue(label: "dev.macduo.backdrop", qos: .userInitiated)
    private static let blurContext = CIContext(options: [.cacheIntermediates: false])
    private var blurPending = false
    private var lastBlurTime: CFTimeInterval = -.infinity
    private let screenContainer = CALayer()
    private let display = CALayer()
    private let edgeMask = CAGradientLayer()
    private let sideMask = CAGradientLayer()
    var onDismiss: (() -> Void)?
    var progress: Double = 0 { didSet { updateGeometry() } }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor
        layer?.masksToBounds = true
        backdrop.contentsGravity = .resizeAspectFill
        layer?.addSublayer(backdrop)
        backdropTint.backgroundColor = NSColor.white.withAlphaComponent(0.68).cgColor
        layer?.addSublayer(backdropTint)
        display.anchorPoint = CGPoint(x: 0.5, y: 0)
        display.contentsGravity = .resize
        display.isDoubleSided = false
        display.masksToBounds = true
        // Flatten the transformed screen into a separate surface. Its negative
        // Z while closing must not place it behind the opaque backdrop layers.
        screenContainer.masksToBounds = true
        layer?.addSublayer(screenContainer)
        screenContainer.addSublayer(display)
        // Multiply horizontal and vertical alpha ramps so all four edges
        // dissolve into the pale blur rather than ending at a hard black rim.
        for mask in [edgeMask, sideMask] {
            mask.colors = [NSColor.clear.cgColor, NSColor.white.cgColor,
                           NSColor.white.cgColor, NSColor.clear.cgColor]
        }
        edgeMask.startPoint = CGPoint(x: 0.5, y: 0)
        edgeMask.endPoint = CGPoint(x: 0.5, y: 1)
        sideMask.startPoint = CGPoint(x: 0, y: 0.5)
        sideMask.endPoint = CGPoint(x: 1, y: 0.5)
        edgeMask.mask = sideMask
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setImage(_ image: CGImage) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        display.contents = image
        // A real frame is the fallback while the first asynchronous blur runs.
        if backdrop.contents == nil { backdrop.contents = image }
        CATransaction.commit()
        updateBackdrop(image)
    }

    private func updateBackdrop(_ image: CGImage) {
        // Keep capture and hinge updates responsive: blur a small texture off
        // the main thread, at most ten times per second, with no queued frames.
        guard !blurPending, CACurrentMediaTime() - lastBlurTime >= 0.1 else { return }
        blurPending = true
        lastBlurTime = CACurrentMediaTime()
        Self.blurQueue.async { [weak self] in
            let source = CIImage(cgImage: image)
            let scale = min(1, 640 / CGFloat(image.width))
            let small = source.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            let blurred = small.clampedToExtent()
                .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 24])
                .cropped(to: small.extent)
            let result = Self.blurContext.createCGImage(blurred, from: small.extent)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.blurPending = false
                if let result {
                    CATransaction.begin()
                    CATransaction.setDisableActions(true)
                    self.backdrop.contents = result
                    CATransaction.commit()
                }
            }
        }
    }

    override func layout() {
        super.layout()
        updateGeometry()
    }

    private func updateGeometry() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // One rigid screen rotates around the bottom horizontal hinge, just
        // like a laptop lid. The desktop texture is never divided or bent.
        let p = CGFloat(progress.isFinite ? max(-1, min(1, progress)) : 0)
        let rotation = -p * 28 * .pi / 180
        let distance = max(bounds.width, bounds.height) * 5
        let isFlat = abs(p) < 0.001
        screenContainer.frame = bounds
        backdrop.isHidden = isFlat
        backdropTint.isHidden = isFlat
        display.mask = isFlat ? nil : edgeMask
        backdrop.frame = bounds
        backdropTint.frame = bounds
        display.cornerRadius = abs(p) * min(bounds.width, bounds.height) * 0.018
        display.bounds = CGRect(origin: .zero, size: bounds.size)
        display.position = CGPoint(x: bounds.midX, y: bounds.minY)
        var transform = CATransform3DIdentity
        transform.m34 = -1 / distance
        transform = CATransform3DRotate(transform, rotation, 1, 0, 0)
        // Keep the complete surface visible when the top projects toward the
        // viewer; use a uniform fit, never a horizontal content compression.
        let fit = 1 / (1 + max(0, sin(rotation)) * bounds.height / distance)
        display.transform = isFlat ? CATransform3DIdentity : CATransform3DScale(transform, fit, fit, fit)
        edgeMask.frame = display.bounds
        sideMask.frame = edgeMask.bounds
        let feather = abs(p) * min(bounds.width, bounds.height) * 0.035
        let vertical = max(0.00001, feather / bounds.height)
        let horizontal = max(0.00001, feather / bounds.width)
        edgeMask.locations = [0, NSNumber(value: Double(vertical)), NSNumber(value: Double(1 - vertical)), 1]
        sideMask.locations = [0, NSNumber(value: Double(horizontal)), NSNumber(value: Double(1 - horizontal)), 1]
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
