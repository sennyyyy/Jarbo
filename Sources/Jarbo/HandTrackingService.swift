import AVFoundation
import CoreGraphics
import Vision

struct TrackedHand: Identifiable {
  let id: HandSide
  let points: [VNHumanHandPoseObservation.JointName: CGPoint]
  let gesture: GestureKind
  let confidence: Float
}

final class HandTrackingService: NSObject, ObservableObject,
  AVCaptureVideoDataOutputSampleBufferDelegate
{
  let session = AVCaptureSession()
  @Published var hands: [TrackedHand] = []
  @Published var running = false
  var roleProvider: (() -> (HandRole, HandRole))?
  var bindingsProvider: (() -> [ActionBinding])?
  var templatesProvider: (() -> [HandPoseTemplate])?
  var motionTemplatesProvider: (() -> [HandMotionTemplate])?
  var automation: AutomationService?
  private let queue = DispatchQueue(label: "jarbo.vision", qos: .userInteractive)
  private var smooth: [HandSide: [VNHumanHandPoseObservation.JointName: CGPoint]] = [:]
  private var history: [HandSide: [(Date, CGPoint)]] = [:]
  private var pinchState: [HandSide: (Bool, Bool)] = [:]
  private var pinchFrames: [HandSide: (Int, Int)] = [:]
  private var lastSwipe: [HandSide: Date] = [:]
  private var gestureCandidate: [HandSide: (GestureKind, Int)] = [:]
  private var activeGesture: [HandSide: GestureKind] = [:]
  private var activeBindings: [HandSide: [ActionBinding]] = [:]
  private var missingFrames: [HandSide: Int] = [:]
  private var motionTrainingHistory: [HandSide: [(Date, [Double])]] = [:]
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
    let request = VNDetectHumanHandPoseRequest()
    request.maximumHandCount = 2
    let handler = VNImageRequestHandler(cvPixelBuffer: pixel, orientation: .up, options: [:])
    guard (try? handler.perform([request])) != nil else { return }
    process(request.results ?? [])
  }
  private func process(_ observations: [VNHumanHandPoseObservation]) {
    var tracked: [TrackedHand] = []
    var candidates:
      [(
        observation: VNHumanHandPoseObservation,
        points: [VNHumanHandPoseObservation.JointName: VNRecognizedPoint], side: HandSide
      )] = observations.compactMap { observation in
        guard let points = try? observation.recognizedPoints(.all) else { return nil }
        return (observation, points, inferSide(observation, points))
      }
    if candidates.count == 2, candidates[0].side == candidates[1].side {
      candidates.sort { displayX($0.points) < displayX($1.points) }
      candidates[0].side = .left
      candidates[1].side = .right
    }
    for candidate in candidates {
      let recognized = candidate.points
      let side = candidate.side
      var points: [VNHumanHandPoseObservation.JointName: CGPoint] = [:]
      var confidence: Float = 1
      for (joint, p) in recognized where p.confidence > 0.35 {
        // The preview is explicitly mirrored like a selfie. Vision reads the unmirrored,
        // landscape pixel buffer, so mirror only X when converting into preview coordinates.
        let raw = CGPoint(x: 1 - p.location.x, y: 1 - p.location.y)
        let old = smooth[side]?[joint] ?? raw
        let alpha: CGFloat = p.confidence > 0.78 ? 0.34 : 0.20
        points[joint] = CGPoint(
          x: old.x + (raw.x - old.x) * alpha, y: old.y + (raw.y - old.y) * alpha)
        confidence = min(confidence, p.confidence)
      }
      smooth[side] = points
      recordMotionFrame(points, side: side)
      let gesture = classify(points, side: side)
      tracked.append(.init(id: side, points: points, gesture: gesture, confidence: confidence))
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
  private func inferSide(
    _ observation: VNHumanHandPoseObservation,
    _ p: [VNHumanHandPoseObservation.JointName: VNRecognizedPoint]
  ) -> HandSide {
    switch observation.chirality {
    case .left: return .left
    case .right: return .right
    default: break
    }
    guard let thumb = p[.thumbTip], let little = p[.littleTip] else {
      return .left
    }
    return thumb.location.x < little.location.x ? .left : .right
  }
  private func displayX(
    _ p: [VNHumanHandPoseObservation.JointName: VNRecognizedPoint]
  ) -> CGFloat {
    1 - (p[.wrist]?.location.x ?? p[.middleMCP]?.location.x ?? 0.5)
  }
  private func classify(_ p: [VNHumanHandPoseObservation.JointName: CGPoint], side: HandSide)
    -> GestureKind
  {
    func d(_ a: VNHumanHandPoseObservation.JointName, _ b: VNHumanHandPoseObservation.JointName)
      -> CGFloat
    {
      guard let x = p[a], let y = p[b] else { return 9 }
      return hypot(x.x - y.x, x.y - y.y)
    }
    let palm = max(d(.indexMCP, .littleMCP), d(.wrist, .middleMCP) * 0.72, 0.04)
    let tips: [VNHumanHandPoseObservation.JointName] = [
      .indexTip, .middleTip, .ringTip, .littleTip,
    ]
    let pips: [VNHumanHandPoseObservation.JointName] = [
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
    // Personal training samples take priority over geometric fallbacks. This lets a user teach
    // Jarbo the difference between their own fist and pinch instead of relying on one generic pose.
    if let trained = closestTemplate(to: p) {
      pinchState[side] = (trained == .pinch, trained == .middlePinch)
      return trained
    }
    let previous = pinchState[side] ?? (false, false)
    let indexRatio = d(.thumbTip, .indexTip) / palm
    let middleRatio = d(.thumbTip, .middleTip) / palm
    let ringRatio = d(.thumbTip, .ringTip) / palm
    var frames = pinchFrames[side] ?? (0, 0)
    let indexReach = d(.indexTip, .wrist) / max(d(.indexMCP, .wrist), 0.02)
    let middleReach = d(.middleTip, .wrist) / max(d(.middleMCP, .wrist), 0.02)
    let otherOpen = extended.dropFirst().filter { $0 }.count
    // A closed fist also places the thumb near the fingertips. Requiring finger reach or another
    // open finger prevents that common pose from being treated as a pinch.
    let indexPoseValid = indexReach > 1.30 && (otherOpen >= 1 || extended[0])
    let middlePoseValid =
      middleReach > 1.27 && (extended[0] || extended.dropFirst(2).contains(true))
    let indexNear = indexRatio < (previous.0 ? 0.78 : 0.54) && indexPoseValid
    let middleNear = middleRatio < (previous.1 ? 0.78 : 0.54) && middlePoseValid
    frames.0 = indexNear ? min(frames.0 + 1, 3) : 0
    frames.1 = middleNear ? min(frames.1 + 1, 3) : 0
    var indexPinch = previous.0 ? indexNear : frames.0 >= 2
    var middlePinch = previous.1 ? middleNear : frames.1 >= 2
    if indexPinch, middlePinch {
      if indexRatio <= middleRatio { middlePinch = false } else { indexPinch = false }
    }
    pinchFrames[side] = frames
    pinchState[side] = (indexPinch, middlePinch)
    if indexPinch { return .pinch }
    if middlePinch { return .middlePinch }
    if ringRatio < 0.50, d(.ringTip, .wrist) > d(.ringMCP, .wrist) * 1.24 {
      return .thumbRing
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
    return .point
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
    side: HandSide, gesture: GestureKind, points: [VNHumanHandPoseObservation.JointName: CGPoint]
  ) {
    DispatchQueue.main.async {
      let roles = self.roleProvider?()
      let role = side == .left ? roles?.0 : roles?.1
      if role == .pointer,
        [.point, .pointLeft, .pointRight, .pointUp, .pointDown, .pinch, .middlePinch]
          .contains(gesture),
        let point = points[.indexTip]
      {
        self.automation?.movePointer(to: point)
      }
      guard role != .disabled else {
        self.releaseControls(for: side)
        return
      }
      let previous = self.gestureCandidate[side]
      let frames = previous?.0 == gesture ? (previous?.1 ?? 0) + 1 : 1
      self.gestureCandidate[side] = (gesture, frames)
      let immediate = gesture == .pinch || gesture == .middlePinch || gesture.category == .motion
      guard frames >= (immediate ? 1 : 2), self.activeGesture[side] != gesture else { return }
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
  func captureRecentMotion(hand side: HandSide) -> [[Double]]? {
    queue.sync { Self.normalizedMotion(motionTrainingHistory[side] ?? []) }
  }
  private func closestTemplate(
    to points: [VNHumanHandPoseObservation.JointName: CGPoint]
  ) -> GestureKind? {
    var distances: [GestureKind: [Double]] = [:]
    for template in templatesProvider?() ?? [] {
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
    guard let best = ranked.first, best.1 < 0.145 else { return nil }
    if ranked.count > 1, ranked[1].1 - best.1 < 0.018 { return nil }
    return best.0
  }
  private static func poseFeatures(
    _ points: [VNHumanHandPoseObservation.JointName: CGPoint], preserveOrientation: Bool = false
  ) -> [Double]? {
    let joints: [VNHumanHandPoseObservation.JointName] = [
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
    _ points: [VNHumanHandPoseObservation.JointName: CGPoint], side: HandSide
  ) {
    guard let wrist = points[.wrist], let index = points[.indexTip],
      let indexMCP = points[.indexMCP], let littleMCP = points[.littleMCP],
      let thumb = points[.thumbTip]
    else { return }
    let palm = max(hypot(indexMCP.x - littleMCP.x, indexMCP.y - littleMCP.y), 0.035)
    let fingerPairs:
      [(VNHumanHandPoseObservation.JointName, VNHumanHandPoseObservation.JointName)] = [
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
