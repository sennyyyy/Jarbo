import AVFoundation
import CoreGraphics

enum CameraRunState: Equatable {
  case off
  case starting
  case on
  case stopping
  case permissionDenied
  case unavailable

  var label: String {
    switch self {
    case .off: "Camera Off"
    case .starting: "Camera Starting…"
    case .on: "Camera On"
    case .stopping: "Camera Stopping…"
    case .permissionDenied: "Camera Permission Required"
    case .unavailable: "Camera Unavailable"
    }
  }
}

enum TrainingCaptureFailure: LocalizedError, Equatable {
  case cameraOff
  case handNotFound(HandSide)
  case incomplete(found: Int)
  case stale
  case lowQuality
  case busy

  var errorDescription: String? {
    switch self {
    case .cameraOff: "Turn the camera on before capturing a pose."
    case .handNotFound(let side): "Show your full \(side.rawValue.lowercased()) hand to the camera."
    case .incomplete(let found): "Only \(found)/21 fresh landmarks are ready. Keep every finger visible."
    case .stale: "The landmark snapshot is stale. Hold the pose steady and try again."
    case .lowQuality: "Landmark confidence is too low. Improve lighting or move the hand into view."
    case .busy: "The detector is busy. Hold the pose and try once more."
    }
  }
}

private final class TrainingCaptureBox: @unchecked Sendable {
  private let lock = NSLock()
  private var value: Result<HandPoseTemplate, TrainingCaptureFailure>?
  func set(_ newValue: Result<HandPoseTemplate, TrainingCaptureFailure>) {
    lock.lock(); value = newValue; lock.unlock()
  }
  func get() -> Result<HandPoseTemplate, TrainingCaptureFailure>? {
    lock.lock(); defer { lock.unlock() }; return value
  }
}

private final class MotionCaptureBox: @unchecked Sendable {
  private let lock = NSLock()
  private var value: [[Double]]?
  func set(_ newValue: [[Double]]?) {
    lock.lock(); value = newValue; lock.unlock()
  }
  func get() -> [[Double]]? {
    lock.lock(); defer { lock.unlock() }; return value
  }
}

final class HandTrackingService: NSObject, ObservableObject, @unchecked Sendable,
  AVCaptureVideoDataOutputSampleBufferDelegate
{
  let session = AVCaptureSession()
  @Published var hands: [TrackedHand] = []
  @Published private(set) var running = false
  @Published private(set) var cameraState = CameraRunState.off
  @Published private(set) var controlsEnabled = true
  @Published private(set) var controlsStatus = "CONTROLS READY · CAMERA OFF"
  @Published var personalizedModelStatus = "CORE ML NOT TRAINED"
  @Published var trainingCaptureStatus = "SHOW THE SELECTED HAND · WAITING FOR 21 JOINTS"
  var roleProvider: (() -> (HandRole, HandRole))?
  var bindingsProvider: (() -> [ActionBinding])?
  var personalTemplatesProvider: (() -> [HandPoseTemplate])?
  var priorTemplatesProvider: (() -> [HandPoseTemplate])?
  var motionTemplatesProvider: (() -> [HandMotionTemplate])?
  var personalizedClassifier: PersonalizedGestureClassifier?
  var automation: AutomationService?
  private let detector: HandLandmarkDetector = AppleVisionHandDetector()
  private let queue = DispatchQueue(label: "jarbo.vision", qos: .userInteractive)
  private let lifecycleLock = NSLock()
  private var startRequested = false
  private var wantsCamera = false
  private var cameraReadyForActions = false
  private var wantsControls = true
  private var wantsConfigurationMode = false
  private var smooth: [HandSide: [HandJoint: CGPoint]] = [:]
  private var latestStablePoints: [HandSide: [HandJoint: CGPoint]] = [:]
  private var latestBackend: [HandSide: HandDetectorBackend] = [:]
  private var lastSeenAt: [HandSide: Date] = [:]
  private var jointSeenAt: [HandSide: [HandJoint: Date]] = [:]
  private var jointConfidence: [HandSide: [HandJoint: Float]] = [:]
  private var trainingStatusHoldUntil = Date.distantPast
  private var lastPublishedAt = Date.distantPast
  private var lastTrainingStatusAt = Date.distantPast
  private var configurationMode = false
  private var lastPersonalPrediction:
    [HandSide: (timestamp: Date, prediction: PersonalizedGestureClassifier.Prediction)] = [:]
  private var history: [HandSide: [(Date, CGPoint)]] = [:]
  private var activePinch: [HandSide: GestureKind] = [:]
  private var pinchCandidate: [HandSide: (GestureKind, Int)] = [:]
  private var lastSwipe: [HandSide: Date] = [:]
  private var gestureCandidate: [HandSide: (GestureKind, Int)] = [:]
  private var activeGesture: [HandSide: GestureKind] = [:]
  private var activeBindings: [HandSide: [ActionBinding]] = [:]
  private var missingFrames: [HandSide: Int] = [:]
  private var motionTrainingHistory: [HandSide: [(Date, [Double])]] = [:]
  private var sessionObservers: [NSObjectProtocol] = []
  private let fingertipJoints: Set<HandJoint> = [
    .thumbTip, .indexTip, .middleTip, .ringTip, .littleTip,
  ]
  override init() {
    super.init()
    let center = NotificationCenter.default
    for name in [
      AVCaptureSession.wasInterruptedNotification,
      AVCaptureSession.runtimeErrorNotification,
      AVCaptureSession.didStopRunningNotification,
    ] {
      sessionObservers.append(
        center.addObserver(forName: name, object: session, queue: nil) { [weak self] _ in
          self?.handleUnexpectedSessionStop()
        })
    }
    sessionObservers.append(
      center.addObserver(
        forName: AVCaptureSession.interruptionEndedNotification, object: session, queue: nil
      ) { [weak self] _ in
        self?.restartAfterInterruptionIfNeeded()
      })
  }
  deinit {
    for observer in sessionObservers { NotificationCenter.default.removeObserver(observer) }
  }
  @MainActor func start() {
    lifecycleLock.lock()
    wantsCamera = true
    guard !startRequested else {
      lifecycleLock.unlock()
      return
    }
    startRequested = true
    lifecycleLock.unlock()
    cameraState = .starting
    trainingCaptureStatus = "CAMERA STARTING…"
    refreshControlsStatus()
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized: configure()
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { [weak self] ok in
        if ok { self?.configure() } else { self?.finishCameraStart(.permissionDenied) }
      }
    case .denied, .restricted: finishCameraStart(.permissionDenied)
    @unknown default: finishCameraStart(.unavailable)
    }
  }
  @MainActor func stop() {
    lifecycleLock.lock()
    wantsCamera = false
    cameraReadyForActions = false
    startRequested = false
    lifecycleLock.unlock()
    // Release synthetic input before AVCapture is allowed to block while stopping.
    // Any already queued frame also re-checks actionDispatchIsAllowed on the main actor.
    releaseAllControls()
    hands = []
    cameraState = .stopping
    trainingCaptureStatus = "CAMERA STOPPING…"
    refreshControlsStatus()
    queue.async { [weak self] in
      guard let self else { return }
      for output in session.outputs.compactMap({ $0 as? AVCaptureVideoDataOutput }) {
        output.setSampleBufferDelegate(nil, queue: nil)
      }
      session.stopRunning()
      session.beginConfiguration()
      for input in session.inputs { session.removeInput(input) }
      for output in session.outputs { session.removeOutput(output) }
      session.commitConfiguration()
      clearTrackingState()
      let stoppedIsStillWanted = cameraIsWanted
      DispatchQueue.main.async {
        guard !stoppedIsStillWanted else { return }
        self.running = false
        self.cameraState = .off
        self.hands = []
        self.trainingCaptureStatus = "CAMERA PAUSED"
        self.refreshControlsStatus()
      }
    }
  }
  @MainActor func setControlsEnabled(_ enabled: Bool) {
    lifecycleLock.lock()
    wantsControls = enabled
    lifecycleLock.unlock()
    controlsEnabled = enabled
    // Clear recognition state on either edge so resuming never dispatches a stale pose.
    queue.async { [weak self] in self?.clearTemporalRecognitionState() }
    if !enabled { releaseAllControls() }
    refreshControlsStatus()
  }
  @MainActor func setConfigurationMode(_ enabled: Bool) {
    lifecycleLock.lock()
    wantsConfigurationMode = enabled
    lifecycleLock.unlock()
    if enabled { releaseAllControls() }
    refreshControlsStatus()
    queue.async { [weak self] in
      guard let self else { return }
      configurationMode = enabled
      clearTemporalRecognitionState()
    }
  }
  private func configure() {
    queue.async { [weak self] in
      guard let self else { return }
      guard cameraIsWanted else {
        finishCameraStart(.off)
        return
      }
      if session.isRunning {
        finishCameraStart(.on)
        return
      }
      session.beginConfiguration()
      if session.canSetSessionPreset(.hd1280x720) {
        session.sessionPreset = .hd1280x720
      } else {
        session.sessionPreset = .medium
      }
      guard
        let camera = AVCaptureDevice.default(
          .builtInWideAngleCamera, for: .video, position: .front),
        let input = try? AVCaptureDeviceInput(device: camera)
      else {
        session.commitConfiguration()
        finishCameraStart(.unavailable)
        return
      }
      do {
        try camera.lockForConfiguration()
        let target = CMTime(value: 1, timescale: 30)
        if camera.activeFormat.videoSupportedFrameRateRanges.contains(where: {
          $0.minFrameRate <= 30 && $0.maxFrameRate >= 30
        }) {
          camera.activeVideoMinFrameDuration = target
          camera.activeVideoMaxFrameDuration = target
        }
        camera.unlockForConfiguration()
      } catch {}
      if session.inputs.isEmpty, session.canAddInput(input) { session.addInput(input) }
      let output: AVCaptureVideoDataOutput
      if let existing = session.outputs.compactMap({ $0 as? AVCaptureVideoDataOutput }).first {
        output = existing
      } else {
        output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
          kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        if session.canAddOutput(output) { session.addOutput(output) }
      }
      output.setSampleBufferDelegate(self, queue: queue)
      if let connection = output.connection(with: .video) {
        if connection.isVideoMirroringSupported {
          connection.automaticallyAdjustsVideoMirroring = false
          connection.isVideoMirrored = false
        }
        if connection.isVideoRotationAngleSupported(0) { connection.videoRotationAngle = 0 }
      }
      session.commitConfiguration()
      guard !session.inputs.isEmpty, !session.outputs.isEmpty else {
        finishCameraStart(.unavailable)
        return
      }
      session.startRunning()
      finishCameraStart(session.isRunning ? .on : .unavailable)
    }
  }
  private func finishCameraStart(_ state: CameraRunState) {
    lifecycleLock.lock()
    let wanted = wantsCamera
    cameraReadyForActions = state == .on && wanted
    if state != .on || !wanted {
      startRequested = false
    }
    lifecycleLock.unlock()
    let resolvedState: CameraRunState = state == .on && !wanted ? .off : state
    DispatchQueue.main.async {
      self.running = resolvedState == .on
      self.cameraState = resolvedState
      switch resolvedState {
      case .on: self.trainingCaptureStatus = "CAMERA LIVE · SHOW THE SELECTED HAND"
      case .permissionDenied:
        self.trainingCaptureStatus = "CAMERA PERMISSION REQUIRED"
        self.releaseAllControls()
      case .unavailable:
        self.trainingCaptureStatus = "NO CAMERA AVAILABLE"
        self.releaseAllControls()
      default: break
      }
      self.refreshControlsStatus()
    }
  }
  private var cameraIsWanted: Bool {
    lifecycleLock.lock()
    defer { lifecycleLock.unlock() }
    return wantsCamera
  }
  private var cameraFramesAreAllowed: Bool {
    lifecycleLock.lock()
    defer { lifecycleLock.unlock() }
    return wantsCamera && cameraReadyForActions
  }
  private var actionDispatchIsAllowed: Bool {
    lifecycleLock.lock()
    defer { lifecycleLock.unlock() }
    return wantsCamera && cameraReadyForActions && wantsControls && !wantsConfigurationMode
  }
  private var configurationIsWanted: Bool {
    lifecycleLock.lock()
    defer { lifecycleLock.unlock() }
    return wantsConfigurationMode
  }
  private func handleUnexpectedSessionStop() {
    lifecycleLock.lock()
    guard wantsCamera, cameraReadyForActions else {
      lifecycleLock.unlock()
      return
    }
    cameraReadyForActions = false
    startRequested = false
    lifecycleLock.unlock()
    let permissionDenied = AVCaptureDevice.authorizationStatus(for: .video) != .authorized
    DispatchQueue.main.async {
      self.releaseAllControls()
      self.running = false
      self.hands = []
      self.cameraState = permissionDenied ? .permissionDenied : .unavailable
      self.trainingCaptureStatus =
        permissionDenied ? "CAMERA PERMISSION REQUIRED" : "CAMERA INTERRUPTED · RETRY AVAILABLE"
      self.automation?.state?.log(
        permissionDenied ? "CAMERA PERMISSION REVOKED · CONTROLS RELEASED" : "CAMERA INTERRUPTED · CONTROLS RELEASED")
      self.refreshControlsStatus()
    }
  }
  private func restartAfterInterruptionIfNeeded() {
    guard cameraIsWanted else { return }
    DispatchQueue.main.async { self.start() }
  }
  @MainActor private func refreshControlsStatus() {
    if !controlsEnabled {
      controlsStatus = "CONTROLS PAUSED"
    } else if configurationIsWanted {
      controlsStatus = "CONTROLS PAUSED · CONFIGURATION"
    } else if cameraState == .on {
      controlsStatus = "CONTROLS ACTIVE"
    } else {
      controlsStatus = "CONTROLS READY · CAMERA OFF"
    }
  }
  @MainActor private func releaseAllControls() {
    releaseControls(for: .left)
    releaseControls(for: .right)
    missingFrames.removeAll()
    automation?.releaseAllMouseButtons()
    automation?.deactivatePointer()
  }
  private func clearTemporalRecognitionState() {
    history.removeAll()
    activePinch.removeAll()
    pinchCandidate.removeAll()
    lastSwipe.removeAll()
    motionTrainingHistory.removeAll()
    lastPersonalPrediction.removeAll()
  }
  private func clearTrackingState() {
    smooth.removeAll()
    latestStablePoints.removeAll()
    latestBackend.removeAll()
    lastSeenAt.removeAll()
    jointSeenAt.removeAll()
    jointConfidence.removeAll()
    clearTemporalRecognitionState()
  }
  func captureOutput(
    _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    autoreleasepool {
      guard cameraFramesAreAllowed else { return }
      guard let pixel = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
      guard let frames = try? detector.detect(in: pixel) else { return }
      guard cameraFramesAreAllowed else { return }
      process(frames)
    }
  }
  private func process(_ observations: [HandLandmarkFrame]) {
    guard cameraFramesAreAllowed else { return }
    var tracked: [TrackedHand] = []
    var candidates = observations
    if candidates.count == 2, candidates[0].side == candidates[1].side {
      candidates.sort { displayX($0.landmarks) < displayX($1.landmarks) }
      candidates[0].side = .left
      candidates[1].side = .right
    }
    for candidate in candidates {
      let recognized = candidate.landmarks
      let side = candidate.side
      // Retain a recent joint briefly when Vision dips below confidence for one frame.
      // This prevents pose capture from failing because of a single missing DIP/MCP point.
      var points = smooth[side] ?? [:]
      var jointTimes = jointSeenAt[side] ?? [:]
      var confidences = jointConfidence[side] ?? [:]
      for (joint, p) in recognized where p.confidence > 0.15 {
        // The preview is explicitly mirrored like a selfie. Vision reads the unmirrored,
        // landscape pixel buffer, so mirror only X when converting into preview coordinates.
        let raw = CGPoint(x: 1 - p.location.x, y: 1 - p.location.y)
        let old = smooth[side]?[joint] ?? raw
        let alpha: CGFloat =
          p.confidence > 0.78
          ? (fingertipJoints.contains(joint) ? 0.50 : 0.32) : (p.confidence > 0.35 ? 0.22 : 0.12)
        points[joint] = CGPoint(
          x: old.x + (raw.x - old.x) * alpha, y: old.y + (raw.y - old.y) * alpha)
        jointTimes[joint] = candidate.timestamp
        confidences[joint] = p.confidence
      }
      points = points.filter {
        candidate.timestamp.timeIntervalSince(jointTimes[$0.key] ?? .distantPast) < 0.35
      }
      smooth[side] = points
      jointSeenAt[side] = jointTimes
      jointConfidence[side] = confidences
      latestStablePoints[side] = points
      latestBackend[side] = candidate.backend
      lastSeenAt[side] = candidate.timestamp
      recordMotionFrame(points, side: side)
      // Configuration mode keeps landmark collection active for training, but avoids
      // expensive classification and prevents controls firing behind the editor.
      let gesture = configurationMode ? GestureKind.unknown : classify(points, side: side)
      tracked.append(
        .init(
          id: side, points: points, gesture: gesture, confidence: candidate.confidence,
          backend: candidate.backend))
      if !configurationMode && actionDispatchIsAllowed {
        dispatch(side: side, gesture: gesture, points: points)
      }
    }
    let seen = Set(tracked.map(\.id))
    let now = Date()
    for side in HandSide.allCases where !seen.contains(side) {
      if now.timeIntervalSince(lastSeenAt[side] ?? .distantPast) > 0.35 {
        smooth.removeValue(forKey: side)
        latestStablePoints.removeValue(forKey: side)
        latestBackend.removeValue(forKey: side)
        jointSeenAt.removeValue(forKey: side)
        jointConfidence.removeValue(forKey: side)
      }
    }
    let shouldPublish = !configurationMode && now.timeIntervalSince(lastPublishedAt) >= (1.0 / 12.0)
    if shouldPublish { lastPublishedAt = now }
    let shouldPublishTrainingStatus =
      configurationMode && now.timeIntervalSince(lastTrainingStatusAt) >= 0.25
    if shouldPublishTrainingStatus { lastTrainingStatusAt = now }
    let readiness = tracked.map { "\($0.id.rawValue.uppercased()) \($0.points.count)/21" }
      .joined(separator: " · ")
    let canPublishTrainingStatus = now >= trainingStatusHoldUntil
    DispatchQueue.main.async {
      guard self.cameraFramesAreAllowed else { return }
      if shouldPublish { self.hands = tracked }
      if (shouldPublish || shouldPublishTrainingStatus) && canPublishTrainingStatus {
        let newStatus = readiness.isEmpty
          ? "SHOW THE SELECTED HAND · WAITING FOR 21 JOINTS"
          : "LANDMARKS · \(readiness)"
        if self.trainingCaptureStatus != newStatus { self.trainingCaptureStatus = newStatus }
      }
      for side in HandSide.allCases {
        if seen.contains(side) {
          self.missingFrames[side] = 0
        } else {
          let count = (self.missingFrames[side] ?? 0) + 1
          self.missingFrames[side] = count
          if count == 3 { self.releaseControls(for: side) }
        }
      }
    }
  }
  private func displayX(
    _ p: [HandJoint: HandLandmark]
  ) -> CGFloat {
    1 - (p[.wrist]?.location.x ?? p[.middleMCP]?.location.x ?? 0.5)
  }
  private func classify(_ p: [HandJoint: CGPoint], side: HandSide)
    -> GestureKind
  {
    func d(_ a: HandJoint, _ b: HandJoint)
      -> CGFloat
    {
      guard let x = p[a], let y = p[b] else { return 9 }
      return hypot(x.x - y.x, x.y - y.y)
    }
    let palm = max(d(.indexMCP, .littleMCP), d(.wrist, .middleMCP) * 0.72, 0.04)
    if let pinch = detectFingerContact(p, side: side, palm: palm) { return pinch }
    let tips: [HandJoint] = [
      .indexTip, .middleTip, .ringTip, .littleTip,
    ]
    let pips: [HandJoint] = [
      .indexPIP, .middlePIP, .ringPIP, .littlePIP,
    ]
    let extended = zip(tips, pips).map { d($0.0, .wrist) > d($0.1, .wrist) * 1.10 }
    let extendedCount = extended.filter { $0 }.count
    if extendedCount >= 3,
      let swipe = detectSwipe(p[.wrist] ?? p[.middleMCP] ?? .zero, side: side)
    {
      return swipe
    }
    if let motion = closestMotionTemplate(side: side) { return motion }
    if let features = Self.poseFeatures(p),
      let prediction = personalizedPrediction(features: features, side: side)
    {
      if prediction.gesture == .unknown, prediction.confidence >= 0.62 { return .unknown }
      if prediction.gesture.category == .staticPose, prediction.confidence >= 0.72 {
        return prediction.gesture
      }
    }
    if let trained = closestTemplate(
      to: p, templates: personalTemplatesProvider?() ?? [], maxError: 0.13, margin: 0.028,
      allowContacts: true)
    {
      return trained
    }
    let thumbExtended = d(.thumbTip, .wrist) > d(.thumbIP, .wrist) * 1.12
    if let tip = p[.thumbTip], let mp = p[.thumbMP], p[.wrist] != nil,
      tip.y < mp.y - palm * 0.13, d(.thumbTip, .wrist) > d(.thumbMP, .wrist) * 1.14,
      extendedCount <= 1
    {
      return .thumbsUp
    }
    if let tip = p[.thumbTip], let mp = p[.thumbMP], p[.wrist] != nil,
      tip.y > mp.y + palm * 0.13, d(.thumbTip, .wrist) > d(.thumbMP, .wrist) * 1.14,
      extendedCount <= 1
    {
      return .thumbsDown
    }
    if extended == [false, false, false, false] { return .fist }
    if extended == [true, true, true, true] { return thumbExtended ? .openPalm : .fourFingers }
    if extended == [false, false, false, true] { return thumbExtended ? .shaka : .pinky }
    if extended == [true, false, false, true] { return thumbExtended ? .spiderMan : .rock }
    if extended == [true, false, false, false] {
      guard let tip = p[.indexTip], let base = p[.indexMCP] else { return .point }
      let dx = tip.x - base.x
      let dy = tip.y - base.y
      if abs(dx) > abs(dy) * 1.05, abs(dx) > palm * 0.42 {
        return dx < 0 ? .pointLeft : .pointRight
      }
      if abs(dy) > palm * 0.42 { return dy < 0 ? .pointUp : .pointDown }
      return .point
    }
    if extended == [true, true, false, false] { return .peace }
    if extended == [true, true, true, false] { return .threeFingers }
    if let prior = closestTemplate(
      to: p, templates: priorTemplatesProvider?() ?? [], maxError: 0.115, margin: 0.035,
      allowContacts: false)
    {
      return prior
    }
    return .unknown
  }
  private func personalizedPrediction(
    features: [Double], side: HandSide
  ) -> PersonalizedGestureClassifier.Prediction? {
    let now = Date()
    if let cached = lastPersonalPrediction[side],
      now.timeIntervalSince(cached.timestamp) < (1.0 / 15.0)
    {
      return cached.prediction
    }
    guard let prediction = personalizedClassifier?.predict(features: features) else { return nil }
    lastPersonalPrediction[side] = (now, prediction)
    return prediction
  }
  private func detectFingerContact(
    _ points: [HandJoint: CGPoint], side: HandSide, palm: CGFloat
  ) -> GestureKind? {
    guard let thumb = points[.thumbTip], let wrist = points[.wrist] else {
      activePinch.removeValue(forKey: side)
      pinchCandidate.removeValue(forKey: side)
      return nil
    }
    let targets:
      [(
        gesture: GestureKind, tip: HandJoint, mcp: HandJoint
      )] = [
        (.pinch, .indexTip, .indexMCP),
        (.middlePinch, .middleTip, .middleMCP),
        (.thumbRing, .ringTip, .ringMCP),
      ]
    let contacts = targets.compactMap { target -> (GestureKind, CGFloat, CGFloat, CGFloat)? in
      guard let tip = points[target.tip], let mcp = points[target.mcp] else { return nil }
      let ratio = hypot(thumb.x - tip.x, thumb.y - tip.y) / palm
      let midpoint = CGPoint(x: (thumb.x + tip.x) / 2, y: (thumb.y + tip.y) / 2)
      let midpointReach = hypot(midpoint.x - wrist.x, midpoint.y - wrist.y) / palm
      let baseReach = max(hypot(mcp.x - wrist.x, mcp.y - wrist.y), 0.02)
      let fingerReach = hypot(tip.x - wrist.x, tip.y - wrist.y) / baseReach
      return (target.gesture, ratio, midpointReach, fingerReach)
    }.sorted { $0.1 < $1.1 }
    if let active = activePinch[side],
      let contact = contacts.first(where: { $0.0 == active }),
      contact.1 < 0.98, contact.2 > 1.12, contact.3 > 1.02
    {
      return active
    }
    activePinch.removeValue(forKey: side)
    guard let best = contacts.first, best.1 < 0.72, best.2 > 1.20, best.3 > 1.05 else {
      pinchCandidate.removeValue(forKey: side)
      return nil
    }
    let secondDistance = contacts.dropFirst().first?.1 ?? 9
    let distinctContact = secondDistance - best.1 > 0.10 || best.1 < 0.38
    guard distinctContact else {
      pinchCandidate.removeValue(forKey: side)
      return nil
    }
    let previous = pinchCandidate[side]
    let frames = previous?.0 == best.0 ? min((previous?.1 ?? 0) + 1, 3) : 1
    pinchCandidate[side] = (best.0, frames)
    guard frames >= 2 else { return nil }
    activePinch[side] = best.0
    return best.0
  }
  private func detectSwipe(_ wrist: CGPoint, side: HandSide) -> GestureKind? {
    var h = history[side] ?? []
    let now = Date()
    h.append((now, wrist))
    h.removeAll { $0.0 < now.addingTimeInterval(-0.34) }
    history[side] = h
    guard now.timeIntervalSince(lastSwipe[side] ?? .distantPast) > 0.72,
      let first = h.first
    else { return nil }
    let dx = wrist.x - first.1.x
    let dy = wrist.y - first.1.y
    guard max(abs(dx), abs(dy)) > 0.050 else { return nil }
    let gesture: GestureKind?
    if abs(dx) > abs(dy) * 1.15 {
      gesture = dx > 0 ? .swipeRight : .swipeLeft
    } else if abs(dy) > abs(dx) * 1.15 {
      gesture = dy > 0 ? .swipeDown : .swipeUp
    } else {
      gesture = nil
    }
    if gesture != nil {
      lastSwipe[side] = now
      history[side] = []
    }
    return gesture
  }
  private func dispatch(
    side: HandSide, gesture: GestureKind, points: [HandJoint: CGPoint]
  ) {
    guard actionDispatchIsAllowed else { return }
    DispatchQueue.main.async {
      guard self.actionDispatchIsAllowed else {
        self.releaseControls(for: side)
        return
      }
      let roles = self.roleProvider?()
      let role = side == .left ? roles?.0 : roles?.1
      if role == .pointer,
        [.point, .pointLeft, .pointRight, .pointUp, .pointDown, .pinch, .middlePinch, .thumbRing]
          .contains(gesture),
        let point = points[.indexTip]
      {
        self.automation?.movePointer(to: point)
      }
      guard role != .disabled else {
        self.releaseControls(for: side)
        return
      }
      let pinchGestures: Set<GestureKind> = [.pinch, .middlePinch, .thumbRing]
      if let active = self.activeGesture[side], pinchGestures.contains(active),
        !pinchGestures.contains(gesture)
      {
        self.releaseControls(for: side)
      }
      let previous = self.gestureCandidate[side]
      let frames = previous?.0 == gesture ? (previous?.1 ?? 0) + 1 : 1
      self.gestureCandidate[side] = (gesture, frames)
      let immediate = pinchGestures.contains(gesture) || gesture.category == .motion
      let requiredFrames = immediate ? 1 : (gesture == .unknown ? 2 : 3)
      guard frames >= requiredFrames, self.activeGesture[side] != gesture else { return }
      self.releaseControls(for: side)
      self.activeGesture[side] = gesture
      let bindings =
        self.bindingsProvider?().filter({
          $0.hand == side && $0.gesture == gesture && $0.enabled
        }) ?? []
      self.activeBindings[side] = bindings
      for binding in bindings { self.automation?.begin(binding) }
    }
  }
  @MainActor private func releaseControls(for side: HandSide) {
    for binding in activeBindings.removeValue(forKey: side) ?? [] { automation?.end(binding) }
    activeGesture.removeValue(forKey: side)
    gestureCandidate.removeValue(forKey: side)
  }
  func captureTemplate(for gesture: GestureKind, hand side: HandSide) -> [Double]? {
    guard let points = hands.first(where: { $0.id == side })?.points else { return nil }
    return Self.poseFeatures(points, preserveOrientation: gesture.category == .orientation)
  }
  func captureTrainingSample(
    for gesture: GestureKind, hand side: HandSide
  ) -> Result<HandPoseTemplate, TrainingCaptureFailure> {
    guard cameraState == .on else { return finishCapture(.failure(.cameraOff), gesture: gesture) }
    let box = TrainingCaptureBox()
    let semaphore = DispatchSemaphore(value: 0)
    queue.async { [weak self] in
      guard let self else { box.set(.failure(.busy)); semaphore.signal(); return }
      let now = Date()
      guard let lastSeen = lastSeenAt[side] else {
        box.set(.failure(.handNotFound(side))); semaphore.signal(); return
      }
      guard now.timeIntervalSince(lastSeen) < 0.25 else {
        box.set(.failure(.stale)); semaphore.signal(); return
      }
      let points = latestStablePoints[side] ?? [:]
      let times = jointSeenAt[side] ?? [:]
      let freshCount = HandJoint.allCases.filter {
        guard let seen = times[$0] else { return false }
        return now.timeIntervalSince(seen) < 0.25 && points[$0] != nil
      }.count
      guard freshCount == HandJoint.allCases.count else {
        box.set(.failure(.incomplete(found: freshCount))); semaphore.signal(); return
      }
      let confidences = jointConfidence[side] ?? [:]
      let average = HandJoint.allCases.reduce(0.0) { $0 + Double(confidences[$1] ?? 0) }
        / Double(HandJoint.allCases.count)
      guard average >= 0.28 else {
        box.set(.failure(.lowQuality)); semaphore.signal(); return
      }
      guard let features = Self.poseFeatures(
        points, preserveOrientation: gesture.category == .orientation)
      else {
        box.set(.failure(.incomplete(found: freshCount))); semaphore.signal(); return
      }
      trainingStatusHoldUntil = now.addingTimeInterval(2.0)
      box.set(.success(.init(
        gesture: gesture, features: features, backend: latestBackend[side], hand: side,
        capturedAt: now)))
      semaphore.signal()
    }
    // Keep the synchronous UI hand-off below the Phase 0 80 ms interaction gate.
    guard semaphore.wait(timeout: .now() + 0.075) == .success, let result = box.get() else {
      return finishCapture(.failure(.busy), gesture: gesture)
    }
    return finishCapture(result, gesture: gesture)
  }
  private func finishCapture(
    _ result: Result<HandPoseTemplate, TrainingCaptureFailure>, gesture: GestureKind
  ) -> Result<HandPoseTemplate, TrainingCaptureFailure> {
    queue.async { [weak self] in self?.trainingStatusHoldUntil = Date().addingTimeInterval(2.0) }
    switch result {
    case .success:
      trainingCaptureStatus = "SAVED \(gesture.displayName.uppercased()) · 21/21 FRESH JOINTS"
    case .failure(let failure):
      trainingCaptureStatus = "CAPTURE FAILED · \(failure.localizedDescription.uppercased())"
    }
    return result
  }
  func captureRecentMotion(hand side: HandSide) -> [[Double]]? {
    let box = MotionCaptureBox()
    let semaphore = DispatchSemaphore(value: 0)
    queue.async { [weak self] in
      box.set(Self.normalizedMotion(self?.motionTrainingHistory[side] ?? []))
      semaphore.signal()
    }
    guard semaphore.wait(timeout: .now() + 0.075) == .success else { return nil }
    return box.get()
  }
  @MainActor func trainPersonalizedModel(samples: [HandPoseTemplate]) {
    guard let personalizedClassifier else {
      personalizedModelStatus = "CORE ML UNAVAILABLE"
      return
    }
    personalizedModelStatus = "TRAINING CORE ML…"
    let readiness = CoreMLTrainingReadiness.evaluate(samples)
    automation?.state?.log("CORE ML BUILD STARTED · \(samples.count) PERSONAL SAMPLES")
    automation?.state?.log("CORE ML READINESS · NO GESTURE \(readiness.noGestureCount)/10")
    for row in readiness.classes where row.count > 0 {
      automation?.state?.log(
        "CORE ML READINESS · \(row.gesture.displayName.uppercased()) \(row.count)/10")
    }
    personalizedClassifier.train(samples: samples) { [weak self] result in
      DispatchQueue.main.async {
        switch result {
        case .success(let count):
          self?.personalizedModelStatus = "CORE ML READY · \(count) SAMPLES"
          self?.automation?.state?.log("CORE ML BUILD READY · \(count) SAMPLES")
        case .failure(let error):
          let previousModelActive = self?.personalizedClassifier?.isAvailable == true
          let retention = previousModelActive ? "PREVIOUS MODEL ACTIVE" : "NO MODEL ACTIVE"
          self?.personalizedModelStatus =
            "TRAINING FAILED · \(retention) · \(error.localizedDescription.uppercased())"
          self?.automation?.state?.log(
            "CORE ML BUILD FAILED · \(retention) · \(error.localizedDescription)")
        }
      }
    }
  }
  @MainActor func deletePersonalizedModel() {
    guard let personalizedClassifier else { return }
    do {
      try personalizedClassifier.deleteModel()
      personalizedModelStatus = "CORE ML NOT TRAINED · SAMPLES PRESERVED"
      automation?.state?.log("PERSONALIZED CORE ML MODEL DELETED · SAMPLES PRESERVED")
    } catch {
      personalizedModelStatus = "DELETE FAILED · \(error.localizedDescription.uppercased())"
      automation?.state?.log("CORE ML DELETE FAILED · \(error.localizedDescription)")
    }
  }
  private func closestTemplate(
    to points: [HandJoint: CGPoint], templates: [HandPoseTemplate],
    maxError: Double, margin: Double, allowContacts: Bool
  ) -> GestureKind? {
    var distances: [GestureKind: [Double]] = [:]
    for template in templates
    where allowContacts || ![.pinch, .middlePinch, .thumbRing].contains(template.gesture) {
      guard
        let features = Self.poseFeatures(
          points, preserveOrientation: template.gesture.category == .orientation),
        template.features.count == features.count
      else { continue }
      let error = zip(features, template.features).reduce(0.0) { partial, pair in
        let delta = pair.0 - pair.1
        return partial + delta * delta
      }
      let rms = sqrt(error / Double(features.count))
      distances[template.gesture, default: []].append(rms)
    }
    let ranked = distances.map { gesture, values -> (GestureKind, Double) in
      let nearest = values.sorted().prefix(3)
      return (gesture, nearest.reduce(0, +) / Double(nearest.count))
    }.sorted { $0.1 < $1.1 }
    guard let best = ranked.first, best.1 < maxError else { return nil }
    if ranked.count > 1, ranked[1].1 - best.1 < margin { return nil }
    return best.0
  }
  private static func poseFeatures(
    _ points: [HandJoint: CGPoint], preserveOrientation: Bool = false
  ) -> [Double]? {
    let joints: [HandJoint] = [
      .thumbTip, .thumbIP, .thumbMP, .thumbCMC,
      .indexTip, .indexDIP, .indexPIP, .indexMCP,
      .middleTip, .middleDIP, .middlePIP, .middleMCP,
      .ringTip, .ringDIP, .ringPIP, .ringMCP,
      .littleTip, .littleDIP, .littlePIP, .littleMCP,
    ]
    guard let wrist = points[.wrist], let middle = points[.middleMCP],
      let index = points[.indexMCP], let little = points[.littleMCP]
    else { return nil }
    let scale = max(hypot(index.x - little.x, index.y - little.y), 0.035)
    let angle = preserveOrientation ? 0 : atan2(middle.y - wrist.y, middle.x - wrist.x) - (.pi / 2)
    let c = cos(-angle)
    let s = sin(-angle)
    var result: [Double] = []
    for joint in joints {
      guard let point = points[joint] else { return nil }
      let x = (point.x - wrist.x) / scale
      let y = (point.y - wrist.y) / scale
      result.append(Double(x * c - y * s))
      result.append(Double(x * s + y * c))
    }
    return result
  }
  private func recordMotionFrame(
    _ points: [HandJoint: CGPoint], side: HandSide
  ) {
    guard let wrist = points[.wrist], let index = points[.indexTip],
      let indexMCP = points[.indexMCP], let littleMCP = points[.littleMCP],
      let thumb = points[.thumbTip]
    else { return }
    let palm = max(hypot(indexMCP.x - littleMCP.x, indexMCP.y - littleMCP.y), 0.035)
    let fingerPairs:
      [(HandJoint, HandJoint)] = [
        (.indexTip, .indexPIP), (.middleTip, .middlePIP), (.ringTip, .ringPIP),
        (.littleTip, .littlePIP),
      ]
    let openness =
      fingerPairs.reduce(0.0) { total, pair in
        guard let tip = points[pair.0], let pip = points[pair.1] else { return total }
        let tipDistance = hypot(tip.x - wrist.x, tip.y - wrist.y)
        let pipDistance = max(hypot(pip.x - wrist.x, pip.y - wrist.y), 0.01)
        return total + Double(tipDistance / pipDistance)
      } / Double(fingerPairs.count)
    let pinch = Double(hypot(thumb.x - index.x, thumb.y - index.y) / palm)
    let frame = [
      Double(index.x), Double(index.y), Double(wrist.x), Double(wrist.y), Double(palm), openness,
      pinch,
    ]
    let now = Date()
    var samples = motionTrainingHistory[side] ?? []
    samples.append((now, frame))
    samples.removeAll { $0.0 < now.addingTimeInterval(-1.35) }
    motionTrainingHistory[side] = samples
  }
  private func closestMotionTemplate(side: HandSide) -> GestureKind? {
    guard let live = Self.normalizedMotion(motionTrainingHistory[side] ?? []) else { return nil }
    let columns = (0..<7).map { column in live.map { $0[column] } }
    let energy = columns.map { ($0.max() ?? 0) - ($0.min() ?? 0) }.max() ?? 0
    guard energy > 0.22 else { return nil }
    var distances: [GestureKind: [Double]] = [:]
    for template in motionTemplatesProvider?() ?? []
    where template.frames.count == live.count && template.gesture.category == .motion {
      let pairs = zip(live.flatMap { $0 }, template.frames.flatMap { $0 })
      var sum = 0.0
      var count = 0
      for pair in pairs {
        let delta = pair.0 - pair.1
        sum += delta * delta
        count += 1
      }
      guard count > 0 else { continue }
      distances[template.gesture, default: []].append(sqrt(sum / Double(count)))
    }
    let ranked = distances.map { gesture, values -> (GestureKind, Double) in
      let nearest = values.sorted().prefix(3)
      return (gesture, nearest.reduce(0, +) / Double(nearest.count))
    }.sorted { $0.1 < $1.1 }
    guard let best = ranked.first, best.1 < 0.34 else { return nil }
    if ranked.count > 1, ranked[1].1 - best.1 < 0.035 { return nil }
    return best.0
  }
  private static func normalizedMotion(_ samples: [(Date, [Double])]) -> [[Double]]? {
    guard samples.count >= 8, let first = samples.first?.1, first.count == 7 else { return nil }
    let frameCount = 24
    let selected = (0..<frameCount).map { index -> [Double] in
      let source = Int(round(Double(index) * Double(samples.count - 1) / Double(frameCount - 1)))
      return samples[source].1
    }
    let originX = first[2]
    let originY = first[3]
    let scale = max(first[4], 0.035)
    return selected.map { frame in
      [
        (frame[0] - originX) / scale, (frame[1] - originY) / scale,
        (frame[2] - originX) / scale, (frame[3] - originY) / scale, frame[4] / scale,
        frame[5], frame[6],
      ]
    }
  }
}
