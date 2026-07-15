import AppKit
import CoreGraphics
import Foundation

@MainActor final class AutomationService: ObservableObject {
  weak var state: AppState?
  private var lastRun: [UUID: Date] = [:]
  private let pointerOverlay = PointerOverlayController()
  private var smoothedPointer: CGPoint?
  private var pointerTimeout: DispatchWorkItem?
  func execute(_ binding: ActionBinding, at point: CGPoint? = nil) {
    guard binding.enabled, Date().timeIntervalSince(lastRun[binding.id] ?? .distantPast) > 0.65
    else { return }
    lastRun[binding.id] = Date()
    state?.log("\(binding.hand.rawValue) · \(binding.name)")
    switch binding.action {
    case .leftClick: mouse(.left, at: point)
    case .rightClick: mouse(.right, at: point)
    case .spaceLeft: key(123, flags: .maskControl)
    case .spaceRight: key(124, flags: .maskControl)
    case .missionControl: key(126, flags: .maskControl)
    case .appExpose: key(125, flags: .maskControl)
    case .showDesktop: key(103, flags: [])
    case .volumeUp: mediaKey(0)
    case .volumeDown: mediaKey(1)
    case .mute: mediaKey(7)
    case .playPause: mediaKey(16)
    case .nextTrack: mediaKey(17)
    case .previousTrack: mediaKey(18)
    case .openURL: if let url = URL(string: binding.value) { NSWorkspace.shared.open(url) }
    case .openApp: openApplication(binding.value)
    case .openFile:
      NSWorkspace.shared.open(
        URL(fileURLWithPath: NSString(string: binding.value).expandingTildeInPath))
    case .webSearch:
      if let q = binding.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
        let u = URL(string: "https://www.google.com/search?q=\(q)")
      {
        NSWorkspace.shared.open(u)
      }
    case .shell: runShell(binding.value)
    case .speak:
      let p = Process()
      p.executableURL = URL(fileURLWithPath: "/usr/bin/say")
      p.arguments = [binding.value]
      try? p.run()
    case .toggleHUD: state?.showHUD.toggle()
    case .note: state?.notes = binding.value
    case .generateImage:
      NotificationCenter.default.post(name: .jarboGenerateImage, object: binding.value)
    }
  }
  func movePointer(to normalized: CGPoint) {
    let frame = NSScreen.main?.frame ?? .zero
    guard frame.width > 0, frame.height > 0 else { return }
    // Use an inner camera region as the full screen. This reduces edge strain and clamps
    // occasional Vision landmarks that briefly jump outside the camera image.
    let x = min(max((normalized.x - 0.08) / 0.84, 0), 1)
    let y = min(max((normalized.y - 0.10) / 0.80, 0), 1)
    let target = CGPoint(x: frame.minX + x * frame.width, y: y * frame.height)
    let previous = smoothedPointer ?? target
    let distance = hypot(target.x - previous.x, target.y - previous.y)
    let alpha: CGFloat = distance > 220 ? 0.72 : (distance > 70 ? 0.46 : 0.24)
    var next = CGPoint(
      x: previous.x + (target.x - previous.x) * alpha,
      y: previous.y + (target.y - previous.y) * alpha)
    if distance < 2.2 { next = previous }
    smoothedPointer = next
    CGEvent(
      mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: next,
      mouseButton: .left)?.post(tap: .cghidEventTap)
    pointerOverlay.show(at: next, screenHeight: frame.height)
    pointerTimeout?.cancel()
    let timeout = DispatchWorkItem { [weak self] in self?.deactivatePointer() }
    pointerTimeout = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.34, execute: timeout)
  }
  func deactivatePointer() {
    pointerTimeout?.cancel()
    pointerTimeout = nil
    smoothedPointer = nil
    pointerOverlay.hide()
  }
  private func mouse(_ button: CGMouseButton, at point: CGPoint?) {
    let p = point ?? NSEvent.mouseLocation
    let screen = CGPoint(x: p.x, y: (NSScreen.main?.frame.height ?? 0) - p.y)
    let down: CGEventType = button == .left ? .leftMouseDown : .rightMouseDown
    let up: CGEventType = button == .left ? .leftMouseUp : .rightMouseUp
    CGEvent(
      mouseEventSource: nil, mouseType: down, mouseCursorPosition: screen, mouseButton: button)?
      .post(tap: .cghidEventTap)
    CGEvent(mouseEventSource: nil, mouseType: up, mouseCursorPosition: screen, mouseButton: button)?
      .post(tap: .cghidEventTap)
  }
  private func key(_ code: CGKeyCode, flags: CGEventFlags) {
    let d = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true)
    d?.flags = flags
    d?.post(tap: .cghidEventTap)
    let u = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false)
    u?.flags = flags
    u?.post(tap: .cghidEventTap)
  }
  private func mediaKey(_ key: Int) {
    let script: String
    switch key {
    case 0:
      script = "set v to output volume of (get volume settings)\nset volume output volume (v + 6)"
    case 1:
      script = "set v to output volume of (get volume settings)\nset volume output volume (v - 6)"
    case 7: script = "set volume with output muted not (output muted of (get volume settings))"
    case 16: script = "tell application \"Music\" to playpause"
    case 17: script = "tell application \"Music\" to next track"
    case 18: script = "tell application \"Music\" to previous track"
    default: return
    }
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    p.arguments = ["-e", script]
    try? p.run()
  }
  private func openApplication(_ value: String) {
    let expanded = NSString(string: value).expandingTildeInPath
    let candidates = [
      URL(fileURLWithPath: expanded),
      URL(fileURLWithPath: "/Applications/\(value.hasSuffix(".app") ? value : value + ".app")"),
    ]
    guard let url = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) })
    else { return }
    NSWorkspace.shared.openApplication(
      at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
  }
  private func runShell(_ command: String) {
    guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/zsh")
    p.arguments = ["-lc", command]
    try? p.run()
  }
}

@MainActor private final class PointerOverlayController {
  private let panel: NSPanel
  private var systemCursorHidden = false
  init() {
    let size = NSSize(width: 34, height: 34)
    panel = NSPanel(
      contentRect: NSRect(origin: .zero, size: size),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered, defer: false)
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.ignoresMouseEvents = true
    panel.level = .screenSaver
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    let circle = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
    circle.material = .hudWindow
    circle.blendingMode = .withinWindow
    circle.state = .active
    circle.wantsLayer = true
    circle.layer?.cornerRadius = size.width / 2
    circle.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.16).cgColor
    circle.layer?.borderColor = NSColor.white.withAlphaComponent(0.86).cgColor
    circle.layer?.borderWidth = 1.5
    circle.layer?.shadowColor = NSColor.systemCyan.cgColor
    circle.layer?.shadowOpacity = 0.65
    circle.layer?.shadowRadius = 7
    circle.layer?.shadowOffset = .zero
    let dot = CALayer()
    dot.frame = CGRect(x: 14, y: 14, width: 6, height: 6)
    dot.cornerRadius = 3
    dot.backgroundColor = NSColor.white.withAlphaComponent(0.92).cgColor
    circle.layer?.addSublayer(dot)
    panel.contentView = circle
  }
  func show(at point: CGPoint, screenHeight: CGFloat) {
    if !systemCursorHidden {
      CGDisplayHideCursor(CGMainDisplayID())
      systemCursorHidden = true
    }
    panel.setFrameOrigin(NSPoint(x: point.x - 17, y: screenHeight - point.y - 17))
    if !panel.isVisible { panel.orderFrontRegardless() }
  }
  func hide() {
    panel.orderOut(nil)
    if systemCursorHidden {
      CGDisplayShowCursor(CGMainDisplayID())
      systemCursorHidden = false
    }
  }
}
extension Notification.Name {
  static let jarboGenerateImage = Notification.Name("JarboGenerateImage")
}
