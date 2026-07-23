import Foundation
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

  func testWebSearchURLPreservesReservedCharactersInsideQueryValue() throws {
    let query = "AT&T + 2+2 = 4"
    let url = try XCTUnwrap(AutomationService.webSearchURL(for: query))
    let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))

    XCTAssertEqual(components.queryItems, [URLQueryItem(name: "q", value: query)])
    XCTAssertTrue(url.absoluteString.contains("AT%26T"))
    XCTAssertTrue(url.absoluteString.contains("2%2B2"))
  }

  @MainActor func testCorruptConfigIsMovedToOneTimeBackup() throws {
    let directory = FileManager.default.temporaryDirectory.appending(
      path: "JarboSettingsTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let config = directory.appending(path: "config.json")
    let invalidData = Data("not-json".utf8)
    try invalidData.write(to: config)

    let backup = try XCTUnwrap(
      AppState.backupCorruptConfig(
        at: config, timestamp: Date(timeIntervalSince1970: 1_234)))

    XCTAssertFalse(FileManager.default.fileExists(atPath: config.path))
    XCTAssertEqual(backup.lastPathComponent, "config-corrupt-1234.json")
    XCTAssertEqual(try Data(contentsOf: backup), invalidData)
  }
}
