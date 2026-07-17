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
enum GestureCategory: String, CaseIterable {
  case staticPose = "Static"
  case motion = "Dynamic"
  case orientation = "Orientation"
}
enum GestureKind: String, Codable, CaseIterable, Identifiable {
  case unknown = "No gesture"
  // Static configurations (legacy raw values are retained so saved v1 configurations decode).
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
  case fourFingers = "Four"
  case pinky = "Pinky"
  case rock = "Rock"
  case shaka = "Shaka"
  case okSign = "OK"
  case italianPinch = "Italian Pinch"
  case fingerGun = "Finger Gun"
  case lShape = "L Shape"
  case vulcanSalute = "Vulcan Salute"
  case crossedFingers = "Crossed Fingers"
  case spiderMan = "Spider-Man"
  case thumbRing = "Thumb + Ring"
  case thumbsUp = "Thumbs up"
  case thumbsDown = "Thumbs down"
  // Dynamic trajectories.
  case swipeLeft = "Swipe left"
  case swipeRight = "Swipe right"
  case swipeUp = "Swipe Up"
  case swipeDown = "Swipe Down"
  case pushForward = "Push Forward"
  case pullBack = "Pull Back"
  case waveLeftRight = "Wave Left-Right"
  case waveUpDown = "Wave Up-Down"
  case circleClockwise = "Circle Clockwise"
  case circleCounterclockwise = "Circle Counterclockwise"
  case drawTriangle = "Draw Triangle"
  case drawSquare = "Draw Square"
  case drawCircle = "Draw Circle"
  case drawCheckmark = "Draw Checkmark"
  case drawX = "Draw X"
  case doubleAirTap = "Double Tap (air)"
  case airClick = "Air Click"
  case grab = "Grab"
  case release = "Release"
  case shakeNo = "Shake No"
  // Wrist/hand orientations.
  case palmCamera = "Palm Facing Camera"
  case backCamera = "Back of Hand Facing Camera"
  case palmUp = "Palm Up"
  case palmDown = "Palm Down"
  case palmLeft = "Palm Left"
  case palmRight = "Palm Right"
  case fingersUp = "Fingers Point Up"
  case fingersDown = "Fingers Point Down"
  case tiltedLeft = "Hand Tilted 45° Left"
  case tiltedRight = "Hand Tilted 45° Right"
  case customA = "Custom A"
  case customB = "Custom B"
  case customC = "Custom C"
  var id: String { rawValue }
  var displayName: String {
    switch self {
    case .pinch: "Finger Heart"
    case .middlePinch: "Thumb + Middle"
    case .threeFingers: "Three"
    default: rawValue
    }
  }
  var category: GestureCategory {
    switch self {
    case .swipeLeft, .swipeRight, .swipeUp, .swipeDown, .pushForward, .pullBack,
      .waveLeftRight, .waveUpDown, .circleClockwise, .circleCounterclockwise, .drawTriangle,
      .drawSquare, .drawCircle, .drawCheckmark, .drawX, .doubleAirTap, .airClick, .grab,
      .release, .shakeNo:
      .motion
    case .palmCamera, .backCamera, .palmUp, .palmDown, .palmLeft, .palmRight, .fingersUp,
      .fingersDown, .tiltedLeft, .tiltedRight:
      .orientation
    default: .staticPose
    }
  }
  static let trainingCatalog: [GestureKind] = [
    .fist, .openPalm, .thumbsUp, .point, .peace, .threeFingers, .fourFingers, .pinky,
    .rock, .shaka, .okSign, .pinch, .italianPinch, .fingerGun, .lShape, .vulcanSalute,
    .crossedFingers, .spiderMan, .middlePinch, .thumbRing,
    .swipeLeft, .swipeRight, .swipeUp, .swipeDown, .pushForward, .pullBack, .waveLeftRight,
    .waveUpDown, .circleClockwise, .circleCounterclockwise, .drawTriangle, .drawSquare,
    .drawCircle, .drawCheckmark, .drawX, .doubleAirTap, .airClick, .grab, .release, .shakeNo,
    .palmCamera, .backCamera, .palmUp, .palmDown, .palmLeft, .palmRight, .fingersUp,
    .fingersDown, .tiltedLeft, .tiltedRight,
  ]
  static let selectableGestures: [GestureKind] =
    trainingCatalog
    + [.thumbsDown, .pointLeft, .pointRight, .pointUp, .pointDown, .customA, .customB, .customC]
}
enum ActionKind: String, Codable, CaseIterable, Identifiable {
  case leftClick = "Left click"
  case rightClick = "Right click"
  case middleClick = "Middle click"
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
  var backend: HandDetectorBackend?
  var hand: HandSide?
  var capturedAt: Date?

  init(
    gesture: GestureKind, features: [Double], backend: HandDetectorBackend? = nil,
    hand: HandSide? = nil, capturedAt: Date? = nil
  ) {
    self.gesture = gesture
    self.features = features
    self.backend = backend
    self.hand = hand
    self.capturedAt = capturedAt
  }
}
struct HandMotionTemplate: Identifiable, Codable, Hashable {
  var id: Int { frames.hashValue ^ gesture.rawValue.hashValue }
  var gesture: GestureKind
  var frames: [[Double]]
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
  @Published var handMotionTemplates: [HandMotionTemplate] = [] { didSet { save() } }
  private(set) var bundledGesturePriors: [HandPoseTemplate] = []
  @Published var notes = "Welcome back. Jarbo systems are online." { didSet { save() } }
  @Published var showHUD = true
  @Published var launchComplete = false
  @Published var selectedViewerURL: URL?
  @Published var commandLog: [String] = ["JARBO INITIALIZED"]
  static let defaults: [ActionBinding] = [
    .init(name: "Primary click", hand: .left, gesture: .pinch, action: .leftClick),
    .init(name: "Context click", hand: .left, gesture: .middlePinch, action: .rightClick),
    .init(name: "Middle click", hand: .left, gesture: .thumbRing, action: .middleClick),
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
  init() {
    loadBundledPriors()
    load()
  }
  var effectivePoseTemplates: [HandPoseTemplate] {
    let personallyTrained = Set(handPoseTemplates.map(\.gesture))
    return handPoseTemplates
      + bundledGesturePriors.filter { !personallyTrained.contains($0.gesture) }
  }
  func restoreEssentialControls() {
    leftRole = .pointer
    rightRole = .controls
    bindings = AppState.defaults
    log("ESSENTIAL HAND CONTROLS RESTORED")
  }
  func addTrainingSample(_ features: [Double], for gesture: GestureKind) {
    addTrainingSample(.init(gesture: gesture, features: features))
  }
  func addTrainingSample(_ sample: HandPoseTemplate) {
    handPoseTemplates.append(sample)
    let gesture = sample.gesture
    let samples = handPoseTemplates.filter { $0.gesture == gesture }
    if samples.count > 10 {
      let removeCount = samples.count - 10
      let removeIDs = Set(samples.prefix(removeCount).map(\.id))
      handPoseTemplates.removeAll { removeIDs.contains($0.id) }
    }
    log("TRAINED \(gesture.displayName.uppercased()) · \(sampleCount(for: gesture))/10 SAMPLES")
  }
  func addMotionTrainingSample(_ frames: [[Double]], for gesture: GestureKind) {
    handMotionTemplates.append(.init(gesture: gesture, frames: frames))
    let samples = handMotionTemplates.filter { $0.gesture == gesture }
    if samples.count > 10 {
      let removeIDs = Set(samples.prefix(samples.count - 10).map(\.id))
      handMotionTemplates.removeAll { removeIDs.contains($0.id) }
    }
    log("TRAINED \(gesture.displayName.uppercased()) · \(sampleCount(for: gesture))/10 SAMPLES")
  }
  func removeTemplate(for gesture: GestureKind) {
    handPoseTemplates.removeAll { $0.gesture == gesture }
    handMotionTemplates.removeAll { $0.gesture == gesture }
  }
  func sampleCount(for gesture: GestureKind) -> Int {
    if gesture.category == .motion {
      return handMotionTemplates.filter { $0.gesture == gesture }.count
    }
    return handPoseTemplates.filter { $0.gesture == gesture }.count
  }
  var coreMLTrainingReady: Bool {
    let staticSamples = Dictionary(grouping: handPoseTemplates.filter {
      $0.gesture.category == .staticPose
    }, by: \.gesture)
    guard (staticSamples[.unknown]?.count ?? 0) >= 10 else { return false }
    return staticSamples.filter { $0.key != .unknown && $0.value.count >= 10 }.count >= 2
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
    var handMotionTemplates: [HandMotionTemplate]?
    var notes: String
  }
  private var saveURL: URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appending(
      path: "Jarbo/config.json")
  }
  private func loadBundledPriors() {
    guard let url = Bundle.main.url(forResource: "GesturePriors", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let priors = try? JSONDecoder().decode([HandPoseTemplate].self, from: data)
    else { return }
    bundledGesturePriors = priors
    log("LOADED \(priors.count) HAGRID LANDMARK PRIORS")
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
    handMotionTemplates = s.handMotionTemplates ?? []
    notes = s.notes
  }
  private func migrate(_ saved: [ActionBinding], from schema: Int) -> [ActionBinding] {
    var result = saved
    if schema < 4 {
      result.removeAll { $0.action == .spaceLeft || $0.action == .spaceRight }
      // Open palm must stay unbound by default because it is the pose used to start a swipe.
      result.removeAll { $0.gesture == .openPalm && $0.action == .missionControl }
      for essential in AppState.defaults {
        if !result.contains(where: { $0.action == essential.action }) { result.append(essential) }
      }
    }
    if schema < 7 {
      let customRing = result.contains {
        $0.hand == .left && $0.gesture == .thumbRing && $0.action != .middleClick
      }
      if customRing {
        result.removeAll { $0.gesture == .thumbRing && $0.action == .middleClick }
      } else if let middle = AppState.defaults.first(where: { $0.action == .middleClick }),
        !result.contains(where: { $0.action == .middleClick })
      {
        result.append(middle)
      }
    }
    return result
  }
  private func save() {
    let s = Saved(
      schemaVersion: 7, theme: theme, leftRole: leftRole, rightRole: rightRole,
      bindings: bindings, pointerSensitivity: pointerSensitivity,
      handPoseTemplates: handPoseTemplates, handMotionTemplates: handMotionTemplates, notes: notes)
    try? FileManager.default.createDirectory(
      at: saveURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    if let data = try? JSONEncoder().encode(s) { try? data.write(to: saveURL, options: .atomic) }
  }
}
