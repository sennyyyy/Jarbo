import SwiftUI

enum JarboTheme: String, CaseIterable, Codable, Identifiable {
  case arcReactor = "Arc Reactor"
  case midnight = "Midnight"
  case crimson = "Crimson"
  case matrix = "Matrix"
  var id: String { rawValue }
  var accent: Color {
    switch self {
    case .arcReactor: .cyan
    case .midnight: .indigo
    case .crimson: .red
    case .matrix: .green
    }
  }
  var secondary: Color {
    switch self {
    case .arcReactor: .blue
    case .midnight: .purple
    case .crimson: .orange
    case .matrix: Color(red: 0.4, green: 1, blue: 0.3)
    }
  }
  var background: Color {
    switch self {
    case .arcReactor: Color(red: 0.01, green: 0.05, blue: 0.08)
    case .midnight: Color(red: 0.025, green: 0.02, blue: 0.08)
    case .crimson: Color(red: 0.08, green: 0.01, blue: 0.015)
    case .matrix: .black
    }
  }
}

enum HandSide: String, Codable, CaseIterable {
  case left = "Left"
  case right = "Right"
}
enum HandRole: String, Codable, CaseIterable, Identifiable {
  case pointer = "Pointer + clicks"
  case controls = "Gesture controls"
  case disabled = "Disabled"
  var id: String { rawValue }
}
enum GestureKind: String, Codable, CaseIterable, Identifiable {
  case point = "Point"
  case pinch = "Pinch"
  case middlePinch = "Middle pinch"
  case fist = "Fist"
  case openPalm = "Open palm"
  case peace = "Peace"
  case thumbsUp = "Thumbs up"
  case swipeLeft = "Swipe left"
  case swipeRight = "Swipe right"
  var id: String { rawValue }
}
enum ActionKind: String, Codable, CaseIterable, Identifiable {
  case leftClick = "Left click"
  case rightClick = "Right click"
  case spaceLeft = "Desktop left"
  case spaceRight = "Desktop right"
  case missionControl = "Mission Control"
  case appExpose = "App Exposé"
  case showDesktop = "Show desktop"
  case volumeUp = "Volume up"
  case volumeDown = "Volume down"
  case mute = "Mute"
  case playPause = "Play / pause"
  case nextTrack = "Next track"
  case previousTrack = "Previous track"
  case openURL = "Open URL"
  case openApp = "Open app"
  case openFile = "Open file / PDF"
  case webSearch = "Search the web"
  case shell = "Run shell command"
  case speak = "Speak text"
  case toggleHUD = "Toggle HUD"
  case note = "Display note"
  case generateImage = "Generate image"
  var id: String { rawValue }
}
struct ActionBinding: Identifiable, Codable, Hashable {
  var id = UUID()
  var name: String
  var hand: HandSide
  var gesture: GestureKind
  var action: ActionKind
  var value: String = ""
  var enabled = true
}
struct WidgetPosition: Codable {
  var x: Double
  var y: Double
}
enum HUDWidgetKind: String, CaseIterable, Codable, Identifiable {
  case camera = "Camera"
  case status = "System"
  case notes = "Notes"
  case music = "Music"
  case visualizer = "Audio"
  case suit = "Suit 3D"
  case viewer = "Viewer"
  case map = "Map"
  case commands = "Commands"
  var id: String { rawValue }
}

@MainActor final class AppState: ObservableObject {
  @Published var theme: JarboTheme = .arcReactor { didSet { save() } }
  @Published var leftRole: HandRole = .pointer { didSet { save() } }
  @Published var rightRole: HandRole = .controls { didSet { save() } }
  @Published var bindings: [ActionBinding] = AppState.defaults { didSet { save() } }
  @Published var notes = "Welcome back. Jarbo systems are online." { didSet { save() } }
  @Published var showHUD = true
  @Published var launchComplete = false
  @Published var selectedViewerURL: URL?
  @Published var commandLog: [String] = ["JARBO INITIALIZED"]
  static let defaults: [ActionBinding] = [
    .init(name: "Primary click", hand: .left, gesture: .pinch, action: .leftClick),
    .init(name: "Context click", hand: .left, gesture: .middlePinch, action: .rightClick),
    .init(name: "Next desktop", hand: .right, gesture: .swipeLeft, action: .spaceRight),
    .init(name: "Previous desktop", hand: .right, gesture: .swipeRight, action: .spaceLeft),
    .init(name: "Mission Control", hand: .right, gesture: .openPalm, action: .missionControl),
    .init(name: "Play / pause", hand: .right, gesture: .fist, action: .playPause),
    .init(name: "Volume up", hand: .right, gesture: .thumbsUp, action: .volumeUp),
  ]
  init() { load() }
  func log(_ text: String) {
    commandLog.insert("\(Date.now.formatted(date: .omitted, time: .standard))  \(text)", at: 0)
    commandLog = Array(commandLog.prefix(40))
  }
  private struct Saved: Codable {
    var theme: JarboTheme
    var leftRole: HandRole
    var rightRole: HandRole
    var bindings: [ActionBinding]
    var notes: String
  }
  private var saveURL: URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appending(
      path: "Jarbo/config.json")
  }
  private func load() {
    guard let data = try? Data(contentsOf: saveURL),
      let s = try? JSONDecoder().decode(Saved.self, from: data)
    else { return }
    theme = s.theme
    leftRole = s.leftRole
    rightRole = s.rightRole
    bindings = s.bindings
    notes = s.notes
  }
  private func save() {
    let s = Saved(
      theme: theme, leftRole: leftRole, rightRole: rightRole, bindings: bindings, notes: notes)
    try? FileManager.default.createDirectory(
      at: saveURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    if let data = try? JSONEncoder().encode(s) { try? data.write(to: saveURL, options: .atomic) }
  }
}
