import Foundation
import os

enum JarboPerformance {
  private static let log = OSLog(
    subsystem: "com.senhong.jarbo", category: .pointsOfInterest)
  private static let lock = NSLock()
  // Access is serialized by `lock`; the compiler cannot infer that external synchronization.
  nonisolated(unsafe) private static var actionsOpenID: OSSignpostID?

  static func beginActionsOpen() {
    lock.lock()
    let id = OSSignpostID(log: log)
    actionsOpenID = id
    lock.unlock()
    os_signpost(.begin, log: log, name: "Actions Open To Interactive", signpostID: id)
  }

  static func actionsInteractive() {
    lock.lock()
    let id = actionsOpenID
    actionsOpenID = nil
    lock.unlock()
    if let id { os_signpost(.end, log: log, name: "Actions Open To Interactive", signpostID: id) }
  }

  static func actionsClosed() {
    os_signpost(.event, log: log, name: "Actions Closed")
  }

  static func bindingEdited() {
    os_signpost(.event, log: log, name: "Binding Edited")
  }

  static func actionsScrolled() {
    os_signpost(.event, log: log, name: "Actions Scrolled")
  }

  static func settingsSnapshotQueued() {
    os_signpost(.event, log: log, name: "Settings Snapshot Queued")
  }

  static func trainingCapture() {
    os_signpost(.event, log: log, name: "Training Capture")
  }
}
