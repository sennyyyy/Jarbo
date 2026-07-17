import AppKit
import ApplicationServices
import SwiftUI

@main struct JarboApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
  var body: some Scene { Settings { EmptyView() } }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
  let state = AppState(), tracker = HandTrackingService(), automation = AutomationService(),
    monitor = SystemMonitor(), voice = VoiceService(), analyzer = ImageAnalyzer(),
    imageGen = ImageGenerationService(), gestureClassifier = PersonalizedGestureClassifier()
  var window: NSWindow!
  var statusItem: NSStatusItem!
  private var hudMenuItem: NSMenuItem!
  private var trackingMenuItem: NSMenuItem!
  private var modelMenuItem: NSMenuItem!
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    automation.state = state
    automation.sensitivityProvider = { [weak state] in state?.pointerSensitivity ?? 0.5 }
    tracker.automation = automation
    tracker.personalizedClassifier = gestureClassifier
    if gestureClassifier.isAvailable { tracker.personalizedModelStatus = "CORE ML READY" }
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
    window.contentView = NSHostingView(rootView: root)
    window.makeKeyAndOrderFront(nil)
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenPrimary]
    setupMenu()
    NotificationCenter.default.addObserver(
      self, selector: #selector(toggleHUD), name: .jarboToggleHUD, object: nil)
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
    statusItem.button?.image = NSImage(
      systemSymbolName: "circle.hexagongrid.fill", accessibilityDescription: "Jarbo")
    let menu = NSMenu()
    menu.delegate = self
    hudMenuItem = menuItem("Hide Jarbo HUD", action: #selector(toggleHUD), key: "j")
    menu.addItem(hudMenuItem)
    menu.addItem(menuItem("Configure Controls…", action: #selector(showControls), key: ","))
    trackingMenuItem = menuItem(
      "Pause Hand Controls", action: #selector(toggleTracking), key: "")
    menu.addItem(trackingMenuItem)
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
    trackingMenuItem.title = tracker.running ? "Pause Hand Controls" : "Resume Hand Controls"
    modelMenuItem.title = tracker.personalizedModelStatus
  }
  @objc private func showHUD() {
    state.showHUD = true
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }
  @objc private func toggleHUD() {
    if window.isVisible {
      window.orderOut(nil)
    } else {
      showHUD()
    }
  }
  @objc private func showControls() {
    showHUD()
    NotificationCenter.default.post(name: .jarboShowActions, object: nil)
  }
  @objc private func toggleTracking() {
    tracker.running ? tracker.stop() : tracker.start()
  }
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag { showHUD() }
    return true
  }
  private func requestAccessibility() {
    let options =
      [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
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
