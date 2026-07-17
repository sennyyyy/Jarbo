import CoreGraphics
import CoreVideo
import Vision

enum HandJoint: String, CaseIterable, Codable, Hashable {
  case wrist
  case thumbCMC, thumbMP, thumbIP, thumbTip
  case indexMCP, indexPIP, indexDIP, indexTip
  case middleMCP, middlePIP, middleDIP, middleTip
  case ringMCP, ringPIP, ringDIP, ringTip
  case littleMCP, littlePIP, littleDIP, littleTip
}

struct HandLandmark: Sendable {
  let location: CGPoint
  let confidence: Float
  /// Optional model-estimated depth. Apple Vision currently leaves this nil;
  /// MediaPipe world landmarks can populate it without changing downstream code.
  let depth: CGFloat?
}

enum HandDetectorBackend: String, Codable, CaseIterable, Identifiable {
  case appleVision = "Apple Vision"
  var id: String { rawValue }
}

struct HandLandmarkFrame: Sendable {
  var side: HandSide
  let landmarks: [HandJoint: HandLandmark]
  let confidence: Float
  let backend: HandDetectorBackend
  let timestamp: Date
}

protocol HandLandmarkDetector: AnyObject {
  var backend: HandDetectorBackend { get }
  func detect(in pixelBuffer: CVPixelBuffer) throws -> [HandLandmarkFrame]
}

/// Native detector and the baseline used to benchmark additional backends.
/// Its output is converted immediately into Jarbo's detector-neutral joint names.
final class AppleVisionHandDetector: HandLandmarkDetector {
  let backend = HandDetectorBackend.appleVision
  private let request: VNDetectHumanHandPoseRequest = {
    let request = VNDetectHumanHandPoseRequest()
    request.maximumHandCount = 2
    return request
  }()

  func detect(in pixelBuffer: CVPixelBuffer) throws -> [HandLandmarkFrame] {
    let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
    try handler.perform([request])
    return (request.results ?? []).compactMap { observation in
      guard let recognized = try? observation.recognizedPoints(.all) else { return nil }
      var landmarks: [HandJoint: HandLandmark] = [:]
      var confidence: Float = 1
      // Keep lower-confidence joints for short-lived capture stabilization. Runtime
      // classification still applies stricter confidence and recency requirements.
      for (visionJoint, point) in recognized where point.confidence > 0.15 {
        guard let joint = Self.jointMap[visionJoint] else { continue }
        landmarks[joint] = .init(location: point.location, confidence: point.confidence, depth: nil)
        confidence = min(confidence, point.confidence)
      }
      return HandLandmarkFrame(
        side: Self.side(for: observation, landmarks: landmarks), landmarks: landmarks,
        confidence: confidence, backend: backend, timestamp: Date())
    }
  }

  private static func side(
    for observation: VNHumanHandPoseObservation, landmarks: [HandJoint: HandLandmark]
  ) -> HandSide {
    switch observation.chirality {
    case .left: return .left
    case .right: return .right
    default:
      guard let thumb = landmarks[.thumbTip], let little = landmarks[.littleTip] else {
        return .left
      }
      return thumb.location.x < little.location.x ? .left : .right
    }
  }

  private static let jointMap: [VNHumanHandPoseObservation.JointName: HandJoint] = [
    .wrist: .wrist,
    .thumbCMC: .thumbCMC, .thumbMP: .thumbMP, .thumbIP: .thumbIP, .thumbTip: .thumbTip,
    .indexMCP: .indexMCP, .indexPIP: .indexPIP, .indexDIP: .indexDIP, .indexTip: .indexTip,
    .middleMCP: .middleMCP, .middlePIP: .middlePIP, .middleDIP: .middleDIP,
    .middleTip: .middleTip,
    .ringMCP: .ringMCP, .ringPIP: .ringPIP, .ringDIP: .ringDIP, .ringTip: .ringTip,
    .littleMCP: .littleMCP, .littlePIP: .littlePIP, .littleDIP: .littleDIP,
    .littleTip: .littleTip,
  ]
}

struct TrackedHand: Identifiable {
  let id: HandSide
  let points: [HandJoint: CGPoint]
  let gesture: GestureKind
  let confidence: Float
  let backend: HandDetectorBackend
}
