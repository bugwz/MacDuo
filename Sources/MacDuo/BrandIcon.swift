import AppKit

/// Shared vector artwork for the app bundle, menu bar and Touch Bar.
/// Coordinates use a 1024-point canvas with its origin at the top left.
enum BrandIcon {
    static let ink = NSColor(srgbRed: 0.13, green: 0.17, blue: 0.23, alpha: 1)

    static func outlines() -> [NSBezierPath] {
        let screen = NSBezierPath()
        screen.move(to: NSPoint(x: 239, y: 218))
        screen.line(to: NSPoint(x: 785, y: 218))
        screen.curve(to: NSPoint(x: 812, y: 252), controlPoint1: NSPoint(x: 808, y: 218), controlPoint2: NSPoint(x: 818, y: 232))
        screen.line(to: NSPoint(x: 754, y: 490))
        screen.curve(to: NSPoint(x: 724, y: 514), controlPoint1: NSPoint(x: 750, y: 505), controlPoint2: NSPoint(x: 740, y: 514))
        screen.line(to: NSPoint(x: 300, y: 514))
        screen.curve(to: NSPoint(x: 270, y: 490), controlPoint1: NSPoint(x: 284, y: 514), controlPoint2: NSPoint(x: 274, y: 505))
        screen.line(to: NSPoint(x: 212, y: 252))
        screen.curve(to: NSPoint(x: 239, y: 218), controlPoint1: NSPoint(x: 206, y: 232), controlPoint2: NSPoint(x: 216, y: 218))
        screen.close()

        let base = NSBezierPath()
        base.move(to: NSPoint(x: 300, y: 596))
        base.line(to: NSPoint(x: 724, y: 596))
        base.curve(to: NSPoint(x: 754, y: 613), controlPoint1: NSPoint(x: 738, y: 596), controlPoint2: NSPoint(x: 747, y: 601))
        base.line(to: NSPoint(x: 831, y: 757))
        base.curve(to: NSPoint(x: 807, y: 794), controlPoint1: NSPoint(x: 842, y: 777), controlPoint2: NSPoint(x: 830, y: 794))
        base.line(to: NSPoint(x: 217, y: 794))
        base.curve(to: NSPoint(x: 193, y: 757), controlPoint1: NSPoint(x: 194, y: 794), controlPoint2: NSPoint(x: 182, y: 777))
        base.line(to: NSPoint(x: 270, y: 613))
        base.curve(to: NSPoint(x: 300, y: 596), controlPoint1: NSPoint(x: 277, y: 601), controlPoint2: NSPoint(x: 286, y: 596))
        base.close()
        // Enlarge the base around the hinge, preserving the gap below the screen.
        let enlargeBase = NSAffineTransform()
        enlargeBase.translateX(by: 512, yBy: 596)
        enlargeBase.scaleX(by: 1.08, yBy: 1.25)
        enlargeBase.translateX(by: -512, yBy: -596)
        base.transform(using: enlargeBase as AffineTransform)
        return [screen, base]
    }

    static func draw(in rect: NSRect, template: Bool = false, appIcon: Bool = false) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        let transform = AffineTransform(translationByX: rect.minX, byY: rect.minY)
        var scaled = transform
        scaled.scale(rect.width / 1024)
        (scaled as NSAffineTransform).concat()
        if appIcon {
            NSColor(srgbRed: 0.96, green: 0.97, blue: 0.99, alpha: 1).setFill()
            NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 200, yRadius: 200).fill()
        }
        (template ? NSColor.black : ink).setStroke()
        for path in outlines() {
            path.lineWidth = template ? 62 : 48
            path.lineJoinStyle = .round
            path.stroke()
        }
    }

    static func image(size: CGFloat, template: Bool = false, appIcon: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { rect in
            draw(in: rect, template: template, appIcon: appIcon)
            return true
        }
        image.isTemplate = template
        image.accessibilityDescription = "MacDuo"
        return image
    }
}
