import AppKit
import ApplicationServices
import AVFoundation
import SwiftUI

@main struct JarboApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
  var body: some Scene { Settings { EmptyView() } }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate,
  NSWindowDelegate
{
  let state = AppState(), tracker = HandTrackingService(), automation = AutomationService(),
    monitor = SystemMonitor(), voice = VoiceService(), analyzer = ImageAnalyzer(),
    imageGen = ImageGenerationService(), gestureClassifier = PersonalizedGestureClassifier()
  var window: NSWindow!
  var statusItem: NSStatusItem!
  private var hudMenuItem: NSMenuItem!
  private var controlsMenuItem: NSMenuItem!
  private var cameraMenuItem: NSMenuItem!
  private var cameraRecoveryMenuItem: NSMenuItem!
  private var modelMenuItem: NSMenuItem!
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    automation.state = state
    automation.sensitivityProvider = { [weak state] in state?.pointerSensitivity ?? 0.5 }
    tracker.automation = automation
    tracker.personalizedClassifier = gestureClassifier
    if gestureClassifier.isAvailable, let error = gestureClassifier.lastErrorMessage {
      tracker.personalizedModelStatus =
        "CORE ML READY · LAST BUILD FAILED · \(error.uppercased())"
    } else if gestureClassifier.isAvailable {
      tracker.personalizedModelStatus = "CORE ML READY"
    } else if let error = gestureClassifier.lastErrorMessage {
      tracker.personalizedModelStatus = "LAST BUILD FAILED · \(error.uppercased())"
    }
    tracker.roleProvider = { [weak state] in
      (state?.leftRole ?? .pointer, state?.rightRole ?? .controls)
    }
    tracker.bindingsProvider = { [weak state] in state?.bindings ?? [] }
    tracker.personalTemplatesProvider = { [weak state] in state?.handPoseTemplates ?? [] }
    tracker.priorTemplatesProvider = { [weak state] in state?.bundledGesturePriors ?? [] }
    tracker.motionTemplatesProvider = { [weak state] in state?.handMotionTemplates ?? [] }
    voice.onCommand = { [weak self] text in self?.handleVoice(text) }
    let root = ControlCenterView().environmentObject(state).environmentObject(tracker)
      .environmentObject(automation).environmentObject(monitor).environmentObject(voice)
      .environmentObject(analyzer).environmentObject(imageGen)
    window = NSWindow(
      contentRect: NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900),
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered, defer: false)
    window.title = "Jarbo"
    window.titlebarAppearsTransparent = true
    window.level = .normal
    window.delegate = self
    window.contentView = NSHostingView(rootView: root)
    window.makeKeyAndOrderFront(nil)
    window.collectionBehavior = [.managed, .participatesInCycle, .fullScreenPrimary]
    setupMenu()
    NotificationCenter.default.addObserver(
      self, selector: #selector(handlePassiveHUDToggle), name: .jarboToggleHUD, object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(toggleCamera), name: .jarboToggleCamera, object: nil)
    requestAccessibility()
  }
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
  func applicationWillTerminate(_ notification: Notification) {
    state.flushSave()
    automation.releaseAllMouseButtons()
    automation.deactivatePointer()
    tracker.stop()
  }
  private func setupMenu() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem.button?.image = JarboMenuIcon.make()
    statusItem.button?.setAccessibilityLabel("Jarbo controls")
    let menu = NSMenu()
    menu.delegate = self
    hudMenuItem = menuItem("Hide Jarbo HUD", action: #selector(toggleHUD), key: "j")
    menu.addItem(hudMenuItem)
    menu.addItem(menuItem("Configure Controls…", action: #selector(showControls), key: ","))
    menu.addItem(.separator())
    controlsMenuItem = menuItem(
      "Pause Hand Controls", action: #selector(toggleControls), key: "")
    menu.addItem(controlsMenuItem)
    cameraMenuItem = menuItem("Turn Camera On", action: #selector(toggleCamera), key: "")
    menu.addItem(cameraMenuItem)
    cameraRecoveryMenuItem = menuItem(
      "Retry Camera", action: #selector(recoverCamera), key: "")
    cameraRecoveryMenuItem.isHidden = true
    menu.addItem(cameraRecoveryMenuItem)
    modelMenuItem = NSMenuItem(title: tracker.personalizedModelStatus, action: nil, keyEquivalent: "")
    modelMenuItem.isEnabled = false
    menu.addItem(modelMenuItem)
    menu.addItem(.separator())
    menu.addItem(menuItem("Quit Jarbo", action: #selector(NSApplication.terminate(_:)), key: "q"))
    statusItem.menu = menu
  }
  private func menuItem(_ title: String, action: Selector, key: String) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
    item.target = self
    return item
  }
  func menuNeedsUpdate(_ menu: NSMenu) {
    hudMenuItem.title = window.isVisible ? "Hide Jarbo HUD" : "Show Jarbo HUD"
    controlsMenuItem.title = tracker.controlsEnabled ? "Pause Hand Controls" : "Resume Hand Controls"
    controlsMenuItem.image = NSImage(
      systemSymbolName: tracker.controlsEnabled ? "hand.raised.fill" : "hand.raised.slash.fill",
      accessibilityDescription: tracker.controlsStatus)
    controlsMenuItem.toolTip = tracker.controlsStatus
    // The persisted intent owns this switch. Actual capture state is displayed by the icon,
    // so permission failure cannot leave a menu item that only ever asks to start again.
    cameraMenuItem.title = state.cameraEnabled ? "Turn Camera Off" : "Turn Camera On"
    cameraMenuItem.image = NSImage(
      systemSymbolName: tracker.running ? "video.fill" : "video.slash",
      accessibilityDescription: tracker.cameraState.label)
    cameraMenuItem.toolTip = tracker.cameraState.label
    cameraMenuItem.isEnabled = true
    cameraRecoveryMenuItem.isHidden = true
    if tracker.cameraState == .permissionDenied {
      cameraRecoveryMenuItem.title = "Open Camera Privacy Settings…"
      cameraRecoveryMenuItem.image = NSImage(
        systemSymbolName: "gearshape.fill", accessibilityDescription: nil)
      cameraRecoveryMenuItem.isHidden = false
    } else if tracker.cameraState == .unavailable, state.cameraEnabled {
      cameraRecoveryMenuItem.title = "Retry Camera"
      cameraRecoveryMenuItem.image = NSImage(
        systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)
      cameraRecoveryMenuItem.isHidden = false
    }
    modelMenuItem.title = tracker.personalizedModelStatus
  }
  @objc private func showHUD() {
    presentHUD(activate: true)
  }
  private func presentHUD(activate: Bool) {
    state.showHUD = true
    if activate {
      window.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
    } else {
      window.orderFront(nil)
    }
  }
  @objc private func toggleHUD() {
    if window.isVisible {
      window.orderOut(nil)
    } else {
      showHUD()
    }
  }
  @objc private func handlePassiveHUDToggle() {
    if window.isVisible { window.orderOut(nil) } else { presentHUD(activate: false) }
  }
  @objc private func showControls() {
    showHUD()
    NotificationCenter.default.post(name: .jarboShowActions, object: nil)
  }
  @objc private func toggleControls() {
    tracker.setControlsEnabled(!tracker.controlsEnabled)
    state.log(tracker.controlsEnabled ? "HAND CONTROLS RESUMED" : "HAND CONTROLS PAUSED")
  }
  @objc private func toggleCamera() {
    if state.cameraEnabled {
      state.cameraEnabled = false
      tracker.stop()
    } else {
      state.cameraEnabled = true
      tracker.start()
    }
  }
  @objc private func recoverCamera() {
    if tracker.cameraState == .permissionDenied {
      openCameraPrivacySettings()
    } else {
      state.cameraEnabled = true
      tracker.start()
    }
  }
  private func openCameraPrivacySettings() {
    guard
      let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")
    else { return }
    NSWorkspace.shared.open(url)
  }
  func applicationDidBecomeActive(_ notification: Notification) {
    guard state.cameraEnabled, tracker.cameraState == .permissionDenied,
      AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    else { return }
    tracker.start()
  }
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag { showHUD() }
    return true
  }
  private func requestAccessibility() {
    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
  }
  private func handleVoice(_ text: String) {
    state.log("VOICE · \(text)")
    if text.contains("show jarbo") || text.contains("open hud") {
      showHUD()
      return
    }
    if text.contains("next desktop") {
      automation.execute(
        .init(name: "Voice desktop", hand: .right, gesture: .swipeLeft, action: .spaceRight))
      return
    }
    if text.contains("previous desktop") {
      automation.execute(
        .init(name: "Voice desktop", hand: .right, gesture: .swipeRight, action: .spaceLeft))
      return
    }
    if text.contains("play") || text.contains("pause") {
      automation.execute(
        .init(name: "Voice media", hand: .right, gesture: .fist, action: .playPause))
      return
    }
    if text.hasPrefix("search ") {
      automation.execute(
        .init(
          name: "Voice search", hand: .right, gesture: .openPalm, action: .webSearch,
          value: String(text.dropFirst(7))))
      return
    }
    for b in state.bindings where text.contains(b.name.lowercased()) { automation.execute(b) }
  }
}
