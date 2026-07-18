import Foundation

enum JarboEventKind: String, Codable, Sendable {
  case gesture
  case trackingLost
  case cancel
}

struct JarboEvent: Codable, Equatable, Sendable {
  var id = UUID()
  var timestamp = Date()
  var kind: JarboEventKind
  var value: String
  var hand: HandSide?

  static func gesture(_ gesture: GestureKind, hand: HandSide? = nil) -> JarboEvent {
    .init(kind: .gesture, value: gesture.rawValue, hand: hand)
  }
}

enum JarboIntentKind: String, Codable, Sendable {
  case playMedia
  case releaseControls
}

struct JarboIntent: Codable, Equatable, Sendable {
  var id = UUID()
  var kind: JarboIntentKind
  var sourceEventID: UUID
}

struct Capability: RawRepresentable, Codable, Hashable, Sendable {
  let rawValue: String

  static let mediaControl = Capability(rawValue: "media.control")
  static let controlRelease = Capability(rawValue: "input.release")
  static let known: Set<Capability> = [.mediaControl, .controlRelease]
}

struct ActionRequest: Codable, Equatable, Sendable {
  var id = UUID()
  var intentID: UUID
  var capability: Capability
  var action: String
  var value: String = ""
}

enum ActionResultStatus: String, Codable, Sendable {
  case succeeded
  case denied
  case cancelled
  case ignored
  case failed
}

struct ActionResult: Codable, Equatable, Sendable {
  var requestID: UUID?
  var status: ActionResultStatus
  var message: String
  var verified = false
}

struct AuditEvent: Codable, Equatable, Sendable {
  var id = UUID()
  var timestamp = Date()
  var eventID: UUID
  var intentID: UUID?
  var requestID: UUID?
  var result: ActionResultStatus
  var detail: String
}

protocol JarboIntentResolving {
  func resolve(_ event: JarboEvent) -> JarboIntent?
}

protocol JarboCapabilityAuthorizing {
  func allows(_ capability: Capability) -> Bool
}

protocol JarboActionExecuting {
  func execute(_ request: ActionRequest) -> ActionResult
}

protocol JarboControlReleasing {
  func releaseAllControls()
}

final class JarboCancellationToken: @unchecked Sendable {
  private let lock = NSLock()
  private var cancelled = false

  func cancel() {
    lock.lock()
    cancelled = true
    lock.unlock()
  }

  var isCancelled: Bool {
    lock.lock()
    defer { lock.unlock() }
    return cancelled
  }
}

struct KnownCapabilityPolicy: JarboCapabilityAuthorizing {
  func allows(_ capability: Capability) -> Bool { Capability.known.contains(capability) }
}

/// Side-effect boundary used by tests and future real intent routing. Recognition produces
/// an intent/request; only an authorized executor can touch a platform adapter.
struct JarboCorePipeline {
  let resolver: any JarboIntentResolving
  let policy: any JarboCapabilityAuthorizing
  let executor: any JarboActionExecuting
  let controlReleaser: any JarboControlReleasing

  func handle(
    _ event: JarboEvent, cancellation: JarboCancellationToken = JarboCancellationToken()
  ) -> ActionResult {
    if event.kind == .trackingLost {
      controlReleaser.releaseAllControls()
      return .init(status: .succeeded, message: "Held controls released", verified: true)
    }
    if event.kind == .cancel || cancellation.isCancelled {
      return .init(status: .cancelled, message: "Cancelled before execution")
    }
    guard event.kind == .gesture, event.value != GestureKind.unknown.rawValue else {
      return .init(status: .ignored, message: "No executable gesture")
    }
    guard let intent = resolver.resolve(event),
      let request = Self.request(for: intent)
    else {
      return .init(status: .ignored, message: "No intent resolved")
    }
    guard policy.allows(request.capability) else {
      return denied(request)
    }
    guard !cancellation.isCancelled else {
      return .init(requestID: request.id, status: .cancelled, message: "Cancelled before execution")
    }
    return executor.execute(request)
  }

  func authorizeAndExecute(
    _ request: ActionRequest, cancellation: JarboCancellationToken = JarboCancellationToken()
  ) -> ActionResult {
    guard policy.allows(request.capability) else { return denied(request) }
    guard !cancellation.isCancelled else {
      return .init(requestID: request.id, status: .cancelled, message: "Cancelled before execution")
    }
    return executor.execute(request)
  }

  private func denied(_ request: ActionRequest) -> ActionResult {
    .init(
      requestID: request.id, status: .denied,
      message: "Capability denied: \(request.capability.rawValue)")
  }

  private static func request(for intent: JarboIntent) -> ActionRequest? {
    switch intent.kind {
    case .playMedia:
      .init(intentID: intent.id, capability: .mediaControl, action: "playPause")
    case .releaseControls:
      .init(intentID: intent.id, capability: .controlRelease, action: "releaseAll")
    }
  }
}

struct MockGestureIntentResolver: JarboIntentResolving {
  func resolve(_ event: JarboEvent) -> JarboIntent? {
    guard event.kind == .gesture, event.value == GestureKind.fist.rawValue else { return nil }
    return .init(kind: .playMedia, sourceEventID: event.id)
  }
}

final class MockVerifiedActionExecutor: JarboActionExecuting {
  private(set) var requests: [ActionRequest] = []

  func execute(_ request: ActionRequest) -> ActionResult {
    requests.append(request)
    return .init(
      requestID: request.id, status: .succeeded, message: "Mock action verified", verified: true)
  }
}

final class MockControlReleaser: JarboControlReleasing {
  private(set) var releaseCount = 0
  func releaseAllControls() { releaseCount += 1 }
}
