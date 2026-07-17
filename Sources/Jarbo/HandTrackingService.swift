import AVFoundation
import CoreGraphics

final class HandTrackingService: NSObject, ObservableObject, @unchecked Sendable,
  AVCaptureVideoDataOutputSampleBufferDelegate
{
  let session = AVCaptureSession()
  @Published var hands: [TrackedHand] = []
  @Published var running = false
  @Published var personalizedModelStatus = "CORE ML NOT TRAINED"
  var roleProvider: (() -> (HandRole, HandRole))?
  var bindingsProvider: (() -> [ActionBinding])?
  var personalTemplatesProvider: (() -> [HandPoseTemplate])?
  var priorTemplatesProvider: (() -> [HandPoseTemplate])?
  var motionTemplatesProvider: (() -> [HandMotionTemplate])?
  var personalizedClassifier: PersonalizedGestureClassifier?
  var automation: AutomationService?
  private let detector: HandLandmarkDetector = AppleVisionHandDetector()
  private let queue = DispatchQueue(label: "jarbo.vision", qos: .userInteractive)
  private var smooth: [HandSide: [HandJoint: CGPoint]] = [:]
  private var history: [HandSide: [(Date, CGPoint)]] = [:]
  private var activePinch: [HandSide: GestureKind] = [:]
  private var pinchCandidate: [HandSide: (GestureKind, Int)] = [:]
  private var lastSwipe: [HandSide: Date] = [:]
  private var gestureCandidate: [HandSide: (GestureKind, Int)] = [:]
  private var activeGesture: [HandSide: GestureKind] = [:]
  private var activeBindings: [HandSide: [ActionBinding]] = [:]
  private var missingFrames: [HandSide: Int] = [:]
  private var motionTrainingHistory: [HandSide: [(Date, [Double])]] = [:]
  private let fingertipJoints: Set<HandJoint> = [
    .thumbTip, .indexTip, .middleTip, .ringTip, .littleTip,
  ]
  func start() {
    guard !running else { return }
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized: configure()
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { [weak self] ok in if ok { self?.configure() } }
    default: return
    }
  }
  func stop() {
    session.stopRunning()
    DispatchQueue.main.async {
      self.releaseControls(for: .left)
      self.releaseControls(for: .right)
      self.running = false
      self.hands = []
    }
  }
  private func configure() {
    queue.async { [weak self] in
      guard let self else { return }
      session.beginConfiguration()
      session.sessionPreset = .high
      guard
        let camera = AVCaptureDevice.default(
          .builtInWideAngleCamera, for: .video, position: .front),
        let input = try? AVCaptureDeviceInput(device: camera)
      else {
        session.commitConfiguration()
        return
      }
      if session.inputs.isEmpty, session.canAddInput(input) { session.addInput(input) }
      let output = AVCaptureVideoDataOutput()
      output.alwaysDiscardsLateVideoFrames = true
      output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
      output.setSampleBufferDelegate(self, queue: queue)
      if session.outputs.isEmpty, session.canAddOutput(output) { session.addOutput(output) }
      if let connection = output.connection(with: .video) {
        if connection.isVideoMirroringSupported {
          connection.automaticallyAdjustsVideoMirroring = false
          connection.isVideoMirrored = false
        }
        if connection.isVideoRotationAngleSupported(0) { connection.videoRotationAngle = 0 }
      }
      session.commitConfiguration()
      guard !session.inputs.isEmpty, !session.outputs.isEmpty else { return }
      session.startRunning()
      DispatchQueue.main.async { self.running = self.session.isRunning }
    }
  }
  func captureOutput(
    _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard let pixel = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    guard let frames = try? detector.detect(in: pixel) else { return }
    process(frames)
  }
  private func process(_ observations: [HandLandmarkFrame]) {
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
      var points: [HandJoint: CGPoint] = [:]
      for (joint, p) in recognized where p.confidence > 0.35 {
        // The preview is explicitly mirrored like a selfie. Vision reads the unmirrored,
        // landscape pixel buffer, so mirror only X when converting into preview coordinates.
        let raw = CGPoint(x: 1 - p.location.x, y: 1 - p.location.y)
        let old = smooth[side]?[joint] ?? raw
        let alpha: CGFloat =
          p.confidence > 0.78 ? (fingertipJoints.contains(joint) ? 0.50 : 0.32) : 0.22
        points[joint] = CGPoint(
          x: old.x + (raw.x - old.x) * alpha, y: old.y + (raw.y - old.y) * alpha)
      }
      smooth[side] = points
      recordMotionFrame(points, side: side)
      let gesture = classify(points, side: side)
      tracked.append(
        .init(
          id: side, points: points, gesture: gesture, confidence: candidate.confidence,
          backend: candidate.backend))
      dispatch(side: side, gesture: gesture, points: points)
    }
    let seen = Set(tracked.map(\.id))
    DispatchQueue.main.async {
      self.hands = tracked
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
      let prediction = personalizedClassifier?.predict(features: features)
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
    DispatchQueue.main.async {
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
  func captureTrainingSample(for gesture: GestureKind, hand side: HandSide) -> HandPoseTemplate? {
    guard let hand = hands.first(where: { $0.id == side }),
      let features = Self.poseFeatures(
        hand.points, preserveOrientation: gesture.category == .orientation)
    else { return nil }
    return .init(
      gesture: gesture, features: features, backend: hand.backend, hand: side, capturedAt: Date())
  }
  func captureRecentMotion(hand side: HandSide) -> [[Double]]? {
    queue.sync { Self.normalizedMotion(motionTrainingHistory[side] ?? []) }
  }
  func trainPersonalizedModel(samples: [HandPoseTemplate]) {
    guard let personalizedClassifier else {
      personalizedModelStatus = "CORE ML UNAVAILABLE"
      return
    }
    personalizedModelStatus = "TRAINING CORE ML…"
    personalizedClassifier.train(samples: samples) { [weak self] result in
      DispatchQueue.main.async {
        switch result {
        case .success(let count):
          self?.personalizedModelStatus = "CORE ML READY · \(count) SAMPLES"
        case .failure(let error):
          self?.personalizedModelStatus = "TRAINING FAILED · \(error.localizedDescription.uppercased())"
        }
      }
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
