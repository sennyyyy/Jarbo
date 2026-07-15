import AppKit
import ApplicationServices
import SwiftUI

@main struct JarboApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
  var body: some Scene { Settings { EmptyView() } }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
  let state = AppState(), tracker = HandTrackingService(), automation = AutomationService(),
    monitor = SystemMonitor(), voice = VoiceService(), analyzer = ImageAnalyzer(),
    imageGen = ImageGenerationService()
  var window: NSWindow!
  var statusItem: NSStatusItem!
  func applicationDidFinishLaunching(_ notification: Notification) {
    automation.state = state
    tracker.automation = automation
    tracker.roleProvider = { [weak state] in
      (state?.leftRole ?? .pointer, state?.rightRole ?? .controls)
    }
    tracker.bindingsProvider = { [weak state] in state?.bindings ?? [] }
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
    requestAccessibility()
  }
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
  func applicationWillTerminate(_ notification: Notification) {
    automation.deactivatePointer()
    tracker.stop()
  }
  private func setupMenu() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem.button?.image = NSImage(
      systemSymbolName: "circle.hexagongrid.fill", accessibilityDescription: "Jarbo")
    let menu = NSMenu()
    menu.addItem(withTitle: "Open Jarbo HUD", action: #selector(showHUD), keyEquivalent: "j")
    menu.addItem(withTitle: "Start camera", action: #selector(startCamera), keyEquivalent: "")
    menu.addItem(.separator())
    menu.addItem(
      withTitle: "Quit Jarbo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    statusItem.menu = menu
  }
  @objc private func showHUD() {
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }
  @objc private func startCamera() { tracker.start() }
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
