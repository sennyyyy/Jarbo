import XCTest
@testable import Jarbo

final class TrainingReadinessTests: XCTestCase {
  private func samples(_ gesture: GestureKind, _ count: Int, featureCount: Int = 40)
    -> [HandPoseTemplate]
  {
    (0..<count).map { index in
      HandPoseTemplate(
        gesture: gesture, features: Array(repeating: Double(index) / 100, count: featureCount))
    }
  }

  func testTenNoGestureAndTwoCompleteStaticClassesAreRequired() {
    let notEnoughRejection = CoreMLTrainingReadiness.evaluate(
      samples(.unknown, 9) + samples(.fist, 10) + samples(.point, 10))
    XCTAssertFalse(notEnoughRejection.canBuild)
    XCTAssertTrue(notEnoughRejection.missingSummary.contains("1 No gesture"))

    let oneClass = CoreMLTrainingReadiness.evaluate(samples(.unknown, 10) + samples(.fist, 10))
    XCTAssertFalse(oneClass.canBuild)
    XCTAssertTrue(oneClass.missingSummary.contains("1 more complete static class"))

    let ready = CoreMLTrainingReadiness.evaluate(
      samples(.unknown, 10) + samples(.fist, 10) + samples(.point, 10))
    XCTAssertTrue(ready.canBuild)
    XCTAssertEqual(ready.completedClassCount, 2)
  }

  func testDynamicOrientationAndInvalidFeaturesNeverEnableStaticModel() {
    let readiness = CoreMLTrainingReadiness.evaluate(
      samples(.unknown, 10) + samples(.fist, 10) + samples(.swipeLeft, 10)
        + samples(.palmCamera, 10) + samples(.point, 10, featureCount: 39))
    XCTAssertFalse(readiness.canBuild)
    XCTAssertEqual(readiness.completedClassCount, 1)
  }

  func testIncompleteExtraClassIsIgnoredAndCountsAreCapped() {
    let readiness = CoreMLTrainingReadiness.evaluate(
      samples(.unknown, 12) + samples(.fist, 11) + samples(.point, 10) + samples(.peace, 4))
    XCTAssertTrue(readiness.canBuild)
    XCTAssertEqual(readiness.noGestureCount, 10)
    XCTAssertEqual(readiness.classes.first(where: { $0.gesture == .fist })?.count, 10)
    XCTAssertEqual(readiness.classes.first(where: { $0.gesture == .peace })?.count, 4)
  }
}
