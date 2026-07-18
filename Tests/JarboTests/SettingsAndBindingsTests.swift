import XCTest
@testable import Jarbo

final class SettingsAndBindingsTests: XCTestCase {
  func testBindingRoundTripAndValidation() throws {
    let valid = ActionBinding(
      name: "Docs", hand: .right, gesture: .point, action: .openURL,
      value: "https://example.com")
    let decoded = try JSONDecoder().decode(
      ActionBinding.self, from: JSONEncoder().encode(valid))
    XCTAssertEqual(decoded, valid)
    XCTAssertNil(valid.validationError)

    var invalid = valid
    invalid.value = "javascript:alert(1)"
    XCTAssertNotNil(invalid.validationError)
  }

  @MainActor func testMissingSettingsFieldsReceiveSafeDefaults() throws {
    let decoded = try JSONDecoder().decode(AppState.Saved.self, from: Data("{}".utf8))
    XCTAssertEqual(decoded.theme, .arcReactor)
    XCTAssertEqual(decoded.leftRole, .pointer)
    XCTAssertEqual(decoded.rightRole, .controls)
    XCTAssertEqual(decoded.bindings, AppState.defaults)
    XCTAssertEqual(decoded.cameraEnabled, nil)
  }

  @MainActor func testLegacyBindingMigrationRestoresSafeEssentials() {
    let migrated = AppState.migrateBindings([], from: 0)
    XCTAssertTrue(migrated.contains(where: { $0.action == .leftClick }))
    XCTAssertTrue(migrated.contains(where: { $0.action == .spaceLeft }))
    XCTAssertTrue(migrated.contains(where: { $0.action == .spaceRight }))
  }
}
