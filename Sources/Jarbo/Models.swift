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

enum HandSide: String, Codable, CaseIterable, Sendable {
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
enum GestureKind: String, Codable, CaseIterable, Identifiable, Sendable {
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
  static let trainingByCategory: [GestureCategory: [GestureKind]] =
    Dictionary(grouping: trainingCatalog, by: \.category)
  static let selectableGestures: [GestureKind] =
    trainingCatalog
    + [.thumbsDown, .pointLeft, .pointRight, .pointUp, .pointDown, .customA, .customB, .customC]
  static let coreMLCatalog: [GestureKind] = {
    let contacts: Set<GestureKind> = [.pinch, .middlePinch, .thumbRing]
    return (trainingCatalog + [.customA, .customB, .customC]).filter {
      $0.category == .staticPose && !contacts.contains($0)
    }
  }()
  var isCoreMLEligible: Bool { Self.coreMLCatalog.contains(self) }
}
enum ActionKind: String, Codable, CaseIterable, Identifiable, Sendable {
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
struct ActionBinding: Identifiable, Codable, Hashable, Sendable {
  var id = UUID()
  var name: String
  var hand: HandSide
  var gesture: GestureKind
  var action: ActionKind
  var value: String = ""
  var enabled = true
  var validationError: String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    switch action {
    case .openURL:
      guard let url = URL(string: trimmed), ["http", "https"].contains(url.scheme?.lowercased() ?? "")
      else { return "Enter a valid http or https URL." }
    case .openApp, .openFile, .webSearch, .shell, .speak, .note, .generateImage:
      if trimmed.isEmpty { return "\(action.rawValue) requires a value." }
    default: break
    }
    return nil
  }
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

struct CoreMLClassReadiness: Identifiable, Equatable {
  var id: GestureKind { gesture }
  let gesture: GestureKind
  let count: Int
  var complete: Bool { count >= 10 }
}

struct CoreMLTrainingReadiness: Equatable {
  let noGestureCount: Int
  let classes: [CoreMLClassReadiness]

  var completedClassCount: Int { classes.filter(\.complete).count }
  var canBuild: Bool { noGestureCount >= 10 && completedClassCount >= 2 }
  var missingSummary: String {
    guard !canBuild else { return "Ready to build from completed static classes." }
    var needs: [String] = []
    if noGestureCount < 10 { needs.append("\(10 - noGestureCount) No gesture") }
    let remainingClasses = max(0, 2 - completedClassCount)
    if remainingClasses > 0 {
      let partial = classes.filter { !$0.complete && $0.count > 0 }
        .sorted { $0.count == $1.count ? $0.gesture.displayName < $1.gesture.displayName : $0.count > $1.count }
        .prefix(remainingClasses)
      for row in partial { needs.append("\(10 - row.count) \(row.gesture.displayName)") }
      if partial.count < remainingClasses {
        needs.append("\(remainingClasses - partial.count) more complete static class\(remainingClasses - partial.count == 1 ? "" : "es")")
      }
    }
    return "Still needed: " + needs.joined(separator: " + ")
  }

  static func evaluate(_ samples: [HandPoseTemplate]) -> CoreMLTrainingReadiness {
    let grouped = Dictionary(grouping: samples.filter { $0.features.count == 40 }, by: \.gesture)
    return .init(
      noGestureCount: min(grouped[.unknown]?.count ?? 0, 10),
      classes: GestureKind.coreMLCatalog.map {
        .init(gesture: $0, count: min(grouped[$0]?.count ?? 0, 10))
      })
  }
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
  @Published var theme: JarboTheme = .arcReactor { didSet { scheduleSave() } }
  @Published var leftRole: HandRole = .pointer { didSet { scheduleSave() } }
  @Published var rightRole: HandRole = .controls { didSet { scheduleSave() } }
  @Published var bindings: [ActionBinding] = AppState.defaults { didSet { scheduleSave() } }
  @Published var pointerSensitivity = 0.5 { didSet { scheduleSave() } }
  @Published var handPoseTemplates: [HandPoseTemplate] = [] { didSet { scheduleSave() } }
  @Published var handMotionTemplates: [HandMotionTemplate] = [] { didSet { scheduleSave() } }
  @Published var cameraEnabled = false { didSet { scheduleSave() } }
  private(set) var bundledGesturePriors: [HandPoseTemplate] = []
  @Published var notes = "Welcome back. Jarbo systems are online." { didSet { scheduleSave() } }
  @Published var showHUD = true
  @Published var launchComplete = false
  @Published var selectedViewerURL: URL?
  @Published var commandLog: [String] = ["JARBO INITIALIZED"]
  @Published var trainingFeedback = "Choose a gesture and collect varied examples."
  private var saveWorkItem: DispatchWorkItem?
  private let persistenceQueue = DispatchQueue(label: "jarbo.settings", qos: .utility)
  private var isLoading = false
  nonisolated static let defaults: [ActionBinding] = [
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
    isLoading = true
    loadBundledPriors()
    load()
    isLoading = false
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
    let existing = handPoseTemplates.filter { $0.gesture == sample.gesture }
    let nearlyIdentical = existing.filter {
      guard $0.features.count == sample.features.count, !sample.features.isEmpty else { return false }
      let squared = zip($0.features, sample.features).reduce(0.0) { total, pair in
        let delta = pair.0 - pair.1
        return total + delta * delta
      }
      return sqrt(squared / Double(sample.features.count)) < 0.018
    }.count
    handPoseTemplates.append(sample)
    let gesture = sample.gesture
    while handPoseTemplates.filter({ $0.gesture == gesture }).count > 10,
      let oldest = handPoseTemplates.firstIndex(where: { $0.gesture == gesture })
    {
      handPoseTemplates.remove(at: oldest)
    }
    trainingFeedback = nearlyIdentical >= 2
      ? "VARIETY WARNING · several \(gesture.displayName) captures are nearly identical. Change angle, distance, lighting, or finger spacing."
      : "SAVED · \(trainingPrompt(for: gesture))"
    log("TRAINED \(gesture.displayName.uppercased()) · \(sampleCount(for: gesture))/10 SAMPLES")
    if nearlyIdentical >= 2 { log("TRAINING VARIETY WARNING · \(gesture.displayName.uppercased())") }
  }
  func addMotionTrainingSample(_ frames: [[Double]], for gesture: GestureKind) {
    handMotionTemplates.append(.init(gesture: gesture, frames: frames))
    while handMotionTemplates.filter({ $0.gesture == gesture }).count > 10,
      let oldest = handMotionTemplates.firstIndex(where: { $0.gesture == gesture })
    {
      handMotionTemplates.remove(at: oldest)
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
    coreMLReadiness.canBuild
  }
  var coreMLReadiness: CoreMLTrainingReadiness {
    CoreMLTrainingReadiness.evaluate(handPoseTemplates)
  }
  func trainingPrompt(for gesture: GestureKind) -> String {
    if gesture == .unknown {
      return "Next rejection example: relaxed hand, partial curl, transition pose, or unrelated motion."
    }
    let prompts = [
      "Move a little closer or farther from the camera.",
      "Shift the hand toward a different part of the frame.",
      "Use a small wrist rotation while keeping the gesture clear.",
      "Try slightly different lighting or palm angle.",
      "Vary finger spacing without changing the gesture.",
    ]
    return prompts[sampleCount(for: gesture) % prompts.count]
  }
  func log(_ text: String) {
    commandLog.insert("\(Date.now.formatted(date: .omitted, time: .standard))  \(text)", at: 0)
    commandLog = Array(commandLog.prefix(40))
  }
  struct Saved: Codable, @unchecked Sendable {
    var schemaVersion: Int?
    var theme: JarboTheme
    var leftRole: HandRole
    var rightRole: HandRole
    var bindings: [ActionBinding]
    var pointerSensitivity: Double?
    var handPoseTemplates: [HandPoseTemplate]?
    var handMotionTemplates: [HandMotionTemplate]?
    var cameraEnabled: Bool?
    var notes: String

    init(
      schemaVersion: Int?, theme: JarboTheme, leftRole: HandRole, rightRole: HandRole,
      bindings: [ActionBinding], pointerSensitivity: Double?,
      handPoseTemplates: [HandPoseTemplate]?, handMotionTemplates: [HandMotionTemplate]?,
      cameraEnabled: Bool?, notes: String
    ) {
      self.schemaVersion = schemaVersion
      self.theme = theme
      self.leftRole = leftRole
      self.rightRole = rightRole
      self.bindings = bindings
      self.pointerSensitivity = pointerSensitivity
      self.handPoseTemplates = handPoseTemplates
      self.handMotionTemplates = handMotionTemplates
      self.cameraEnabled = cameraEnabled
      self.notes = notes
    }

    enum CodingKeys: String, CodingKey {
      case schemaVersion, theme, leftRole, rightRole, bindings, pointerSensitivity
      case handPoseTemplates, handMotionTemplates, cameraEnabled, notes
    }

    init(from decoder: Decoder) throws {
      let values = try decoder.container(keyedBy: CodingKeys.self)
      schemaVersion = try? values.decodeIfPresent(Int.self, forKey: .schemaVersion)
      theme = (try? values.decodeIfPresent(JarboTheme.self, forKey: .theme)) ?? .arcReactor
      leftRole = (try? values.decodeIfPresent(HandRole.self, forKey: .leftRole)) ?? .pointer
      rightRole = (try? values.decodeIfPresent(HandRole.self, forKey: .rightRole)) ?? .controls
      bindings = (try? values.decodeIfPresent([ActionBinding].self, forKey: .bindings))
        ?? AppState.defaults
      pointerSensitivity = try? values.decodeIfPresent(Double.self, forKey: .pointerSensitivity)
      handPoseTemplates = try? values.decodeIfPresent(
        [HandPoseTemplate].self, forKey: .handPoseTemplates)
      handMotionTemplates = try? values.decodeIfPresent(
        [HandMotionTemplate].self, forKey: .handMotionTemplates)
      cameraEnabled = try? values.decodeIfPresent(Bool.self, forKey: .cameraEnabled)
      notes = (try? values.decodeIfPresent(String.self, forKey: .notes))
        ?? "Welcome back. Jarbo systems are online."
    }
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
    guard let data = try? Data(contentsOf: saveURL) else { return }
    guard let s = try? JSONDecoder().decode(Saved.self, from: data) else {
      let backup = saveURL.deletingLastPathComponent().appending(
        path: "config-corrupt-\(Int(Date().timeIntervalSince1970)).json")
      try? FileManager.default.copyItem(at: saveURL, to: backup)
      log("SETTINGS RECOVERY · INVALID CONFIG BACKED UP")
      return
    }
    theme = s.theme
    leftRole = s.leftRole
    rightRole = s.rightRole
    bindings = Self.migrateBindings(s.bindings, from: s.schemaVersion ?? 0)
    pointerSensitivity = (s.schemaVersion ?? 0) < 4 ? 0.5 : (s.pointerSensitivity ?? 0.5)
    handPoseTemplates = s.handPoseTemplates ?? []
    handMotionTemplates = s.handMotionTemplates ?? []
    cameraEnabled = s.cameraEnabled ?? false
    notes = s.notes
  }
  static func migrateBindings(_ saved: [ActionBinding], from schema: Int) -> [ActionBinding] {
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
  private func scheduleSave() {
    guard !isLoading else { return }
    saveWorkItem?.cancel()
    let work = DispatchWorkItem { [weak self] in self?.saveNow() }
    saveWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
  }
  func flushSave() {
    saveWorkItem?.cancel()
    saveWorkItem = nil
    let snapshot = savedSnapshot
    let url = saveURL
    persistenceQueue.sync { Self.write(snapshot, to: url) }
  }
  private func saveNow() {
    JarboPerformance.settingsSnapshotQueued()
    let snapshot = savedSnapshot
    let url = saveURL
    persistenceQueue.async { Self.write(snapshot, to: url) }
  }
  private var savedSnapshot: Saved {
    Saved(
      schemaVersion: 8, theme: theme, leftRole: leftRole, rightRole: rightRole,
      bindings: bindings, pointerSensitivity: pointerSensitivity,
      handPoseTemplates: handPoseTemplates, handMotionTemplates: handMotionTemplates,
      cameraEnabled: cameraEnabled, notes: notes)
  }
  nonisolated private static func write(_ snapshot: Saved, to url: URL) {
    try? FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    if let data = try? JSONEncoder().encode(snapshot) {
      try? data.write(to: url, options: .atomic)
    }
  }
}
