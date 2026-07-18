import AppKit

enum JarboMenuIcon {
  static func make() -> NSImage {
    let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
      NSColor.black.setStroke()
      let outer = NSBezierPath(ovalIn: rect.insetBy(dx: 2.0, dy: 2.0))
      outer.lineWidth = 1.5
      outer.stroke()
      let core = NSBezierPath(ovalIn: rect.insetBy(dx: 5.3, dy: 5.3))
      core.lineWidth = 1.2
      core.stroke()
      let notch = NSBezierPath()
      notch.move(to: NSPoint(x: 9, y: 16))
      notch.line(to: NSPoint(x: 9, y: 13.8))
      notch.move(to: NSPoint(x: 14.9, y: 5.3))
      notch.line(to: NSPoint(x: 13.1, y: 6.4))
      notch.move(to: NSPoint(x: 3.1, y: 5.3))
      notch.line(to: NSPoint(x: 4.9, y: 6.4))
      notch.lineWidth = 1.5
      notch.lineCapStyle = .round
      notch.stroke()
      return true
    }
    image.isTemplate = true
    image.accessibilityDescription = "Jarbo menu"
    return image
  }
}
