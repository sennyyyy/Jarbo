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
  case pointLeft = "Point left"
  case pointRight = "Point right"
  case pointUp = "Point up"
  case pointDown = "Point down"
  case pinch = "Pinch"
  case middlePinch = "Middle pinch"
  case fist = "Fist"
  case openPalm = "Open palm"
  case peace = "Peace"
  case threeFingers = "Three fingers"
  case thumbsUp = "Thumbs up"
  case thumbsDown = "Thumbs down"
  case swipeLeft = "Swipe left"
  case swipeRight = "Swipe right"
  case customA = "Custom A"
  case customB = "Custom B"
  case customC = "Custom C"
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
struct HandPoseTemplate: Identifiable, Codable, Hashable {
  var id: Int { features.hashValue ^ gesture.rawValue.hashValue }
  var gesture: GestureKind
  var features: [Double]
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
  @Published var pointerSensitivity = 0.5 { didSet { save() } }
  @Published var handPoseTemplates: [HandPoseTemplate] = [] { didSet { save() } }
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
    .init(name: "Mission Control", hand: .right, gesture: .peace, action: .missionControl),
    .init(name: "Play / pause", hand: .right, gesture: .fist, action: .playPause),
    .init(name: "Volume up", hand: .right, gesture: .thumbsUp, action: .volumeUp),
    .init(name: "Volume down", hand: .right, gesture: .thumbsDown, action: .volumeDown),
    .init(name: "Previous track", hand: .right, gesture: .pointLeft, action: .previousTrack),
    .init(name: "Next track", hand: .right, gesture: .pointRight, action: .nextTrack),
    .init(name: "App Expose", hand: .right, gesture: .threeFingers, action: .appExpose),
  ]
  init() { load() }
  func restoreEssentialControls() {
    leftRole = .pointer
    rightRole = .controls
    bindings = AppState.defaults
    log("ESSENTIAL HAND CONTROLS RESTORED")
  }
  func addTrainingSample(_ features: [Double], for gesture: GestureKind) {
    handPoseTemplates.append(.init(gesture: gesture, features: features))
    let samples = handPoseTemplates.filter { $0.gesture == gesture }
    if samples.count > 8 {
      let removeCount = samples.count - 8
      let removeIDs = Set(samples.prefix(removeCount).map(\.id))
      handPoseTemplates.removeAll { removeIDs.contains($0.id) }
    }
    log("TRAINED \(gesture.rawValue.uppercased()) · \(sampleCount(for: gesture))/8 SAMPLES")
  }
  func removeTemplate(for gesture: GestureKind) {
    handPoseTemplates.removeAll { $0.gesture == gesture }
  }
  func sampleCount(for gesture: GestureKind) -> Int {
    handPoseTemplates.filter { $0.gesture == gesture }.count
  }
  func log(_ text: String) {
    commandLog.insert("\(Date.now.formatted(date: .omitted, time: .standard))  \(text)", at: 0)
    commandLog = Array(commandLog.prefix(40))
  }
  private struct Saved: Codable {
    var schemaVersion: Int?
    var theme: JarboTheme
    var leftRole: HandRole
    var rightRole: HandRole
    var bindings: [ActionBinding]
    var pointerSensitivity: Double?
    var handPoseTemplates: [HandPoseTemplate]?
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
    bindings = migrate(s.bindings, from: s.schemaVersion ?? 0)
    pointerSensitivity = (s.schemaVersion ?? 0) < 4 ? 0.5 : (s.pointerSensitivity ?? 0.5)
    handPoseTemplates = s.handPoseTemplates ?? []
    notes = s.notes
  }
  private func migrate(_ saved: [ActionBinding], from schema: Int) -> [ActionBinding] {
    guard schema < 4 else { return saved }
    var result = saved.filter { $0.action != .spaceLeft && $0.action != .spaceRight }
    // Open palm must stay unbound by default because it is the pose used to start a swipe.
    result.removeAll { $0.gesture == .openPalm && $0.action == .missionControl }
    for essential in AppState.defaults {
      if !result.contains(where: { $0.action == essential.action }) { result.append(essential) }
    }
    return result
  }
  private func save() {
    let s = Saved(
      schemaVersion: 4, theme: theme, leftRole: leftRole, rightRole: rightRole,
      bindings: bindings, pointerSensitivity: pointerSensitivity,
      handPoseTemplates: handPoseTemplates, notes: notes)
    try? FileManager.default.createDirectory(
      at: saveURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    if let data = try? JSONEncoder().encode(s) { try? data.write(to: saveURL, options: .atomic) }
  }
}
