import XCTest
@testable import Jarbo

final class CorePipelineTests: XCTestCase {
  func testMockGestureTraversesVerifiedVerticalSlice() {
    let executor = MockVerifiedActionExecutor()
    let releaser = MockControlReleaser()
    let pipeline = JarboCorePipeline(
      resolver: MockGestureIntentResolver(), policy: KnownCapabilityPolicy(), executor: executor,
      controlReleaser: releaser)

    let result = pipeline.handle(.gesture(.fist, hand: .right))

    XCTAssertEqual(result.status, .succeeded)
    XCTAssertTrue(result.verified)
    XCTAssertEqual(executor.requests.map(\.action), ["playPause"])
  }

  func testUnknownCapabilityIsDeniedWithoutCallingExecutor() {
    let executor = MockVerifiedActionExecutor()
    let pipeline = JarboCorePipeline(
      resolver: MockGestureIntentResolver(), policy: KnownCapabilityPolicy(), executor: executor,
      controlReleaser: MockControlReleaser())
    let request = ActionRequest(
      intentID: UUID(), capability: Capability(rawValue: "unknown.capability"), action: "unsafe")

    let result = pipeline.authorizeAndExecute(request)

    XCTAssertEqual(result.status, .denied)
    XCTAssertTrue(executor.requests.isEmpty)
  }

  func testNoGestureCannotExecuteAnAction() {
    let executor = MockVerifiedActionExecutor()
    let pipeline = JarboCorePipeline(
      resolver: MockGestureIntentResolver(), policy: KnownCapabilityPolicy(), executor: executor,
      controlReleaser: MockControlReleaser())

    XCTAssertEqual(pipeline.handle(.gesture(.unknown)).status, .ignored)
    XCTAssertTrue(executor.requests.isEmpty)
  }

  func testCancellationPreventsExecution() {
    let executor = MockVerifiedActionExecutor()
    let pipeline = JarboCorePipeline(
      resolver: MockGestureIntentResolver(), policy: KnownCapabilityPolicy(), executor: executor,
      controlReleaser: MockControlReleaser())
    let token = JarboCancellationToken()
    token.cancel()

    XCTAssertEqual(pipeline.handle(.gesture(.fist), cancellation: token).status, .cancelled)
    XCTAssertTrue(executor.requests.isEmpty)
  }

  func testTrackingLossReleasesControlsWithoutActionExecution() {
    let executor = MockVerifiedActionExecutor()
    let releaser = MockControlReleaser()
    let pipeline = JarboCorePipeline(
      resolver: MockGestureIntentResolver(), policy: KnownCapabilityPolicy(), executor: executor,
      controlReleaser: releaser)
    let event = JarboEvent(kind: .trackingLost, value: "", hand: .left)

    let result = pipeline.handle(event)

    XCTAssertEqual(result.status, .succeeded)
    XCTAssertTrue(result.verified)
    XCTAssertEqual(releaser.releaseCount, 1)
    XCTAssertTrue(executor.requests.isEmpty)
  }
}
