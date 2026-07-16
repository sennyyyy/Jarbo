import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

@MainActor final class AutomationService: ObservableObject {
  @Published private(set) var accessibilityGranted = false
  @Published private(set) var lastOutput = "WAITING FOR GESTURE"
  weak var state: AppState?
  var sensitivityProvider: (() -> Double)?
  private var lastRun: [UUID: Date] = [:]
  private let pointerOverlay = PointerOverlayController()
  private var pointerPosition: CGPoint?
  private var lastHandPoint: CGPoint?
  private var filteredDelta = CGPoint.zero
  private var pointerTimeout: DispatchWorkItem?
  private var permissionTimer: Timer?
  private var lastAccessWarning = Date.distantPast
  private var heldButtons: [CGMouseButton: CGPoint] = [:]
  init() {
    refreshAccessibility()
    permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) {
      [weak self] _ in
      Task { @MainActor in self?.refreshAccessibility() }
    }
  }
  func execute(_ binding: ActionBinding, at point: CGPoint? = nil) {
    guard binding.enabled, Date().timeIntervalSince(lastRun[binding.id] ?? .distantPast) > 0.65
    else { return }
    lastRun[binding.id] = Date()
    state?.log("\(binding.hand.rawValue) · \(binding.name)")
    switch binding.action {
    case .leftClick: mouse(.left, at: point)
    case .rightClick: mouse(.right, at: point)
    case .spaceLeft: shortcut(123, modifier: 59, label: "DESKTOP LEFT")
    case .spaceRight: shortcut(124, modifier: 59, label: "DESKTOP RIGHT")
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
  func begin(_ binding: ActionBinding, at point: CGPoint? = nil) {
    guard binding.enabled else { return }
    state?.log("\(binding.hand.rawValue) · \(binding.name)")
    switch binding.action {
    case .leftClick: mouseDown(.left, at: point)
    case .rightClick: mouseDown(.right, at: point)
    default: execute(binding, at: point)
    }
  }
  func end(_ binding: ActionBinding) {
    switch binding.action {
    case .leftClick: mouseUp(.left)
    case .rightClick: mouseUp(.right)
    default: break
    }
  }
  func movePointer(to normalized: CGPoint) {
    let frame = NSScreen.main?.frame ?? .zero
    guard frame.width > 0, frame.height > 0, ensureAccessibility(for: "POINTER") else { return }
    let currentCursor =
      CGEvent(source: nil)?.location
      ?? CGPoint(
        x: frame.midX, y: frame.height / 2)
    guard let previousHand = lastHandPoint else {
      lastHandPoint = normalized
      pointerPosition = currentCursor
      pointerOverlay.show(at: currentCursor, screenHeight: frame.height)
      armPointerTimeout()
      return
    }
    let raw = CGPoint(x: normalized.x - previousHand.x, y: normalized.y - previousHand.y)
    lastHandPoint = normalized
    // Ignore a discontinuity caused by a lost/reacquired landmark or a handedness flip.
    guard abs(raw.x) < 0.14, abs(raw.y) < 0.14 else {
      filteredDelta = .zero
      return
    }
    let deadzone: CGFloat = 0.0026
    let dx = abs(raw.x) < deadzone ? 0 : raw.x
    let dy = abs(raw.y) < deadzone ? 0 : raw.y
    filteredDelta = CGPoint(
      x: filteredDelta.x * 0.68 + dx * 0.32,
      y: filteredDelta.y * 0.68 + dy * 0.32)
    let speed = hypot(filteredDelta.x, filteredDelta.y)
    let sensitivity = CGFloat(min(max(sensitivityProvider?() ?? 0.32, 0.15), 1.2))
    let gain = min(2.25, (0.72 + speed * 26) * sensitivity)
    let previous = pointerPosition ?? currentCursor
    let next = CGPoint(
      x: min(max(frame.minX, previous.x + filteredDelta.x * frame.width * gain), frame.maxX - 1),
      y: min(max(0, previous.y + filteredDelta.y * frame.height * gain), frame.height - 1))
    pointerPosition = next
    let source = CGEventSource(stateID: .hidSystemState)
    source?.localEventsSuppressionInterval = 0
    let dragButton = heldButtons.keys.first
    let moveType: CGEventType =
      dragButton == .left
      ? .leftMouseDragged : (dragButton == .right ? .rightMouseDragged : .mouseMoved)
    CGEvent(
      mouseEventSource: source, mouseType: moveType, mouseCursorPosition: next,
      mouseButton: dragButton ?? .left)?.post(tap: .cghidEventTap)
    pointerOverlay.show(at: next, screenHeight: frame.height)
    lastOutput = "POINTER ACTIVE · RELATIVE MODE"
    armPointerTimeout()
  }
  private func armPointerTimeout() {
    pointerTimeout?.cancel()
    let timeout = DispatchWorkItem { [weak self] in self?.deactivatePointer() }
    pointerTimeout = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.42, execute: timeout)
  }
  func deactivatePointer() {
    pointerTimeout?.cancel()
    pointerTimeout = nil
    pointerPosition = nil
    lastHandPoint = nil
    filteredDelta = .zero
    pointerOverlay.hide()
  }
  func requestAccessibility() {
    _ = CGRequestPostEventAccess()
    let options =
      [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
    if let url = URL(
      string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    {
      NSWorkspace.shared.open(url)
    }
    refreshAccessibility()
  }
  func refreshAccessibility() {
    accessibilityGranted = AXIsProcessTrusted() && CGPreflightPostEventAccess()
  }
  private func ensureAccessibility(for action: String) -> Bool {
    refreshAccessibility()
    guard accessibilityGranted else {
      lastOutput = "ACCESSIBILITY REQUIRED · \(action) BLOCKED"
      if Date().timeIntervalSince(lastAccessWarning) > 4 {
        state?.log("ACCESSIBILITY REQUIRED — control event blocked")
        lastAccessWarning = Date()
      }
      return false
    }
    return true
  }
  private func mouse(_ button: CGMouseButton, at point: CGPoint?) {
    guard ensureAccessibility(for: button == .left ? "LEFT CLICK" : "RIGHT CLICK") else { return }
    let screen = point ?? pointerPosition ?? CGEvent(source: nil)?.location ?? .zero
    let down: CGEventType = button == .left ? .leftMouseDown : .rightMouseDown
    let up: CGEventType = button == .left ? .leftMouseUp : .rightMouseUp
    let source = CGEventSource(stateID: .hidSystemState)
    source?.localEventsSuppressionInterval = 0
    let downEvent = CGEvent(
      mouseEventSource: source, mouseType: down, mouseCursorPosition: screen, mouseButton: button)
    let upEvent = CGEvent(
      mouseEventSource: source, mouseType: up, mouseCursorPosition: screen, mouseButton: button)
    downEvent?.setIntegerValueField(.mouseEventClickState, value: 1)
    upEvent?.setIntegerValueField(.mouseEventClickState, value: 1)
    downEvent?.post(tap: .cghidEventTap)
    upEvent?.post(tap: .cghidEventTap)
    lastOutput = button == .left ? "LEFT CLICK SENT" : "RIGHT CLICK SENT"
  }
  private func mouseDown(_ button: CGMouseButton, at point: CGPoint?) {
    guard heldButtons[button] == nil,
      ensureAccessibility(for: button == .left ? "LEFT HOLD" : "RIGHT HOLD")
    else { return }
    let screen = point ?? pointerPosition ?? CGEvent(source: nil)?.location ?? .zero
    let type: CGEventType = button == .left ? .leftMouseDown : .rightMouseDown
    let source = CGEventSource(stateID: .hidSystemState)
    source?.localEventsSuppressionInterval = 0
    let event = CGEvent(
      mouseEventSource: source, mouseType: type, mouseCursorPosition: screen, mouseButton: button)
    event?.setIntegerValueField(.mouseEventClickState, value: 1)
    event?.post(tap: .cghidEventTap)
    heldButtons[button] = screen
    lastOutput = button == .left ? "LEFT CLICK HELD · RELEASE PINCH TO DROP" : "RIGHT CLICK HELD"
  }
  private func mouseUp(_ button: CGMouseButton) {
    guard heldButtons.removeValue(forKey: button) != nil else { return }
    let screen = pointerPosition ?? CGEvent(source: nil)?.location ?? .zero
    let type: CGEventType = button == .left ? .leftMouseUp : .rightMouseUp
    let source = CGEventSource(stateID: .hidSystemState)
    source?.localEventsSuppressionInterval = 0
    let event = CGEvent(
      mouseEventSource: source, mouseType: type, mouseCursorPosition: screen, mouseButton: button)
    event?.setIntegerValueField(.mouseEventClickState, value: 1)
    event?.post(tap: .cghidEventTap)
    lastOutput = button == .left ? "LEFT CLICK RELEASED" : "RIGHT CLICK RELEASED"
  }
  func releaseAllMouseButtons() {
    for button in Array(heldButtons.keys) { mouseUp(button) }
  }
  private func key(_ code: CGKeyCode, flags: CGEventFlags) {
    guard ensureAccessibility(for: "KEYBOARD CONTROL") else { return }
    let source = CGEventSource(stateID: .hidSystemState)
    source?.localEventsSuppressionInterval = 0
    let d = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true)
    d?.flags = flags
    d?.post(tap: .cghidEventTap)
    let u = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false)
    u?.flags = flags
    u?.post(tap: .cghidEventTap)
    lastOutput = "KEYBOARD CONTROL SENT"
  }
  private func shortcut(_ code: CGKeyCode, modifier: CGKeyCode, label: String) {
    guard ensureAccessibility(for: label) else { return }
    let source = CGEventSource(stateID: .hidSystemState)
    source?.localEventsSuppressionInterval = 0
    let modifierDown = CGEvent(keyboardEventSource: source, virtualKey: modifier, keyDown: true)
    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true)
    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false)
    let modifierUp = CGEvent(keyboardEventSource: source, virtualKey: modifier, keyDown: false)
    modifierDown?.flags = .maskControl
    keyDown?.flags = .maskControl
    keyUp?.flags = .maskControl
    modifierUp?.flags = []
    modifierDown?.post(tap: .cghidEventTap)
    keyDown?.post(tap: .cghidEventTap)
    keyUp?.post(tap: .cghidEventTap)
    modifierUp?.post(tap: .cghidEventTap)
    lastOutput = "\(label) SENT · CONTROL + ARROW"
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
