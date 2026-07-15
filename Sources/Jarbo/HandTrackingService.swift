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
  var automation: AutomationService?
  private let queue = DispatchQueue(label: "jarbo.vision", qos: .userInteractive)
  private var smooth: [HandSide: [VNHumanHandPoseObservation.JointName: CGPoint]] = [:]
  private var history: [HandSide: [(Date, CGPoint)]] = [:]
  private var pinchState: [HandSide: (Bool, Bool)] = [:]
  private var lastGesture: [HandSide: (GestureKind, Date)] = [:]
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
    request.revision = VNDetectHumanHandPoseRequestRevision1
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
        let alpha: CGFloat = p.confidence > 0.75 ? 0.42 : 0.24
        points[joint] = CGPoint(
          x: old.x + (raw.x - old.x) * alpha, y: old.y + (raw.y - old.y) * alpha)
        confidence = min(confidence, p.confidence)
      }
      smooth[side] = points
      let gesture = classify(points, side: side)
      tracked.append(.init(id: side, points: points, gesture: gesture, confidence: confidence))
      dispatch(side: side, gesture: gesture, points: points)
    }
    DispatchQueue.main.async { self.hands = tracked }
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
    let palm = max(d(.wrist, .middleMCP), 0.04)
    let previous = pinchState[side] ?? (false, false)
    let indexRatio = d(.thumbTip, .indexTip) / palm
    let middleRatio = d(.thumbTip, .middleTip) / palm
    let indexPinch = previous.0 ? indexRatio < 0.66 : indexRatio < 0.46
    let middlePinch = previous.1 ? middleRatio < 0.66 : middleRatio < 0.46
    pinchState[side] = (indexPinch, middlePinch)
    if indexPinch { return .pinch }
    if middlePinch { return .middlePinch }
    let tips: [VNHumanHandPoseObservation.JointName] = [
      .indexTip, .middleTip, .ringTip, .littleTip,
    ]
    let pips: [VNHumanHandPoseObservation.JointName] = [
      .indexPIP, .middlePIP, .ringPIP, .littlePIP,
    ]
    let extended = zip(tips, pips).map { (p[$0.0]?.y ?? 1) < (p[$0.1]?.y ?? 0) }
    if extended == [false, false, false, false] { return .fist }
    if extended == [true, true, true, true] {
      return detectSwipe(p[.wrist] ?? .zero, side: side) ?? .openPalm
    }
    if extended == [true, false, false, false] { return .point }
    if extended == [true, true, false, false] { return .peace }
    if let t = p[.thumbTip], let w = p[.wrist], t.y < w.y - palm * 0.6 { return .thumbsUp }
    return .point
  }
  private func detectSwipe(_ wrist: CGPoint, side: HandSide) -> GestureKind? {
    var h = history[side] ?? []
    let now = Date()
    h.append((now, wrist))
    h.removeAll { $0.0 < now.addingTimeInterval(-0.45) }
    history[side] = h
    guard let first = h.first, abs(wrist.x - first.1.x) > 0.22 else { return nil }
    return wrist.x > first.1.x ? .swipeRight : .swipeLeft
  }
  private func dispatch(
    side: HandSide, gesture: GestureKind, points: [VNHumanHandPoseObservation.JointName: CGPoint]
  ) {
    DispatchQueue.main.async {
      let roles = self.roleProvider?()
      let role = side == .left ? roles?.0 : roles?.1
      if role == .pointer,
        gesture == .point || gesture == .pinch || gesture == .middlePinch,
        let point = points[.indexTip]
      {
        self.automation?.movePointer(to: point)
      }
      guard role != .disabled else { return }
      let previous = self.lastGesture[side]
      if previous?.0 == gesture, Date().timeIntervalSince(previous?.1 ?? .distantPast) < 0.45 {
        return
      }
      self.lastGesture[side] = (gesture, Date())
      for b in self.bindingsProvider?().filter({
        $0.hand == side && $0.gesture == gesture && $0.enabled
      }) ?? [] { self.automation?.execute(b) }
    }
  }
}
