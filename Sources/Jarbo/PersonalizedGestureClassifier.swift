import CoreML
import CreateML
import Foundation
import TabularData

/// Trains a small tabular Core ML model from Jarbo's normalized landmark features.
/// The saved model contains no camera frames—only the user's labeled landmark vectors.
final class PersonalizedGestureClassifier: @unchecked Sendable {
  struct Prediction: Sendable {
    let gesture: GestureKind
    let confidence: Double
  }

  private let lock = NSLock()
  private var model: MLModel?
  private let featureCount = 40

  init() { loadSavedModel() }

  var lastErrorMessage: String? {
    try? String(contentsOf: errorURL, encoding: .utf8)
  }

  var isAvailable: Bool {
    lock.lock()
    defer { lock.unlock() }
    return model != nil
  }

  func predict(features: [Double]) -> Prediction? {
    guard features.count == featureCount else { return nil }
    lock.lock()
    let currentModel = model
    lock.unlock()
    guard let currentModel,
      let provider = try? MLDictionaryFeatureProvider(dictionary: Self.input(features)),
      let output = try? currentModel.prediction(from: provider),
      let labelName = currentModel.modelDescription.predictedFeatureName,
      let label = output.featureValue(for: labelName)?.stringValue,
      let gesture = GestureKind(rawValue: label)
    else { return nil }

    var confidence = 1.0
    if let probabilitiesName = currentModel.modelDescription.predictedProbabilitiesName,
      let probabilities = output.featureValue(for: probabilitiesName)?.dictionaryValue,
      let number = probabilities[label]
    {
      confidence = number.doubleValue
    }
    return .init(gesture: gesture, confidence: confidence)
  }

  func train(
    samples: [HandPoseTemplate], completion: @escaping @Sendable (Result<Int, Error>) -> Void
  ) {
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      do {
        // Orientation samples intentionally retain wrist rotation and therefore use a
        // different feature space. The first personalized model handles static poses only.
        let candidates = samples.filter {
          $0.features.count == self.featureCount
            && ($0.gesture == .unknown || $0.gesture.isCoreMLEligible)
        }
        let grouped = Dictionary(grouping: candidates, by: \.gesture)
        let completedLabels = Set(grouped.compactMap { $0.value.count >= 10 ? $0.key : nil })
        let usable = candidates.filter { completedLabels.contains($0.gesture) }
        let labels = Set(usable.map(\.gesture))
        guard labels.count >= 3, labels.contains(.unknown) else {
          throw TrainingError.insufficientClasses
        }
        var table = DataFrame()
        table.append(column: Column(name: "gesture", contents: usable.map { $0.gesture.rawValue }))
        for index in 0..<self.featureCount {
          table.append(
            column: Column(
              name: Self.featureName(index), contents: usable.map { $0.features[index] }))
        }
        let featureNames = (0..<self.featureCount).map(Self.featureName)
        let classifier = try MLBoostedTreeClassifier(
          trainingData: table, targetColumn: "gesture", featureColumns: featureNames)

        let directory = self.modelDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let stagedSource = directory.appending(
          path: "PersonalGestureClassifier-\(UUID().uuidString).mlmodel")
        let stagedCompiled = directory.appending(
          path: "PersonalGestureClassifier-\(UUID().uuidString).mlmodelc",
          directoryHint: .isDirectory)
        let stagedMetadata = directory.appending(
          path: "PersonalGestureClassifier-\(UUID().uuidString).json")
        var temporaryURLs = [stagedSource, stagedCompiled, stagedMetadata]
        defer {
          for url in temporaryURLs where FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
          }
        }

        try classifier.write(to: stagedSource, metadata: nil)
        let compiled = try MLModel.compileModel(at: stagedSource)
        temporaryURLs.append(compiled)
        try FileManager.default.copyItem(at: compiled, to: stagedCompiled)
        _ = try MLModel(contentsOf: stagedCompiled, configuration: Self.makeConfiguration())
        let metadata = ModelMetadata(
          featureVersion: 1, createdAt: Date(), classes: labels.map(\.rawValue).sorted(),
          sampleCount: usable.count,
          backends: Set(usable.compactMap { $0.backend?.rawValue }).sorted())
        try JSONEncoder().encode(metadata).write(to: stagedMetadata, options: .atomic)

        // Validate every new artifact before replacing the currently working model. Each
        // replacement is atomic on the application-support volume, and the compiled model—the
        // runtime-critical artifact—is committed last.
        try self.replaceItem(at: self.sourceModelURL, with: stagedSource)
        try self.replaceItem(at: self.metadataURL, with: stagedMetadata)
        try self.replaceItem(at: self.compiledModelURL, with: stagedCompiled)
        let loaded = try MLModel(
          contentsOf: self.compiledModelURL, configuration: Self.makeConfiguration())
        try? FileManager.default.removeItem(at: errorURL)
        self.lock.lock()
        self.model = loaded
        self.lock.unlock()
        completion(.success(usable.count))
      } catch {
        try? error.localizedDescription.write(to: self.errorURL, atomically: true, encoding: .utf8)
        completion(.failure(error))
      }
    }
  }

  private func loadSavedModel() {
    guard FileManager.default.fileExists(atPath: compiledModelURL.path),
      let loaded = try? MLModel(
        contentsOf: compiledModelURL, configuration: Self.makeConfiguration())
    else { return }
    model = loaded
  }

  func deleteModel() throws {
    for url in [sourceModelURL, compiledModelURL, metadataURL, errorURL] where
      FileManager.default.fileExists(atPath: url.path)
    {
      try FileManager.default.removeItem(at: url)
    }
    lock.lock()
    model = nil
    lock.unlock()
  }

  private var modelDirectory: URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appending(path: "Jarbo/Models", directoryHint: .isDirectory)
  }

  private var compiledModelURL: URL {
    modelDirectory.appending(path: "PersonalGestureClassifier.mlmodelc", directoryHint: .isDirectory)
  }

  private var sourceModelURL: URL {
    modelDirectory.appending(path: "PersonalGestureClassifier.mlmodel")
  }

  private var metadataURL: URL { modelDirectory.appending(path: "PersonalGestureClassifier.json") }
  private var errorURL: URL { modelDirectory.appending(path: "PersonalGestureClassifier.error.txt") }

  private static func makeConfiguration() -> MLModelConfiguration {
    let configuration = MLModelConfiguration()
    configuration.computeUnits = .all
    return configuration
  }

  private func replaceItem(at destination: URL, with staged: URL) throws {
    if FileManager.default.fileExists(atPath: destination.path) {
      _ = try FileManager.default.replaceItemAt(destination, withItemAt: staged)
    } else {
      try FileManager.default.moveItem(at: staged, to: destination)
    }
  }

  private static func featureName(_ index: Int) -> String { "landmark_\(index)" }

  private static func input(_ features: [Double]) -> [String: MLFeatureValue] {
    Dictionary(uniqueKeysWithValues: features.enumerated().map {
      (featureName($0.offset), MLFeatureValue(double: $0.element))
    })
  }

  enum TrainingError: LocalizedError {
    case insufficientClasses
    case insufficientSamples

    var errorDescription: String? {
      switch self {
      case .insufficientClasses:
        "Train No gesture plus at least two gestures before building the Core ML model."
      case .insufficientSamples:
        "Every included gesture needs ten samples before building the Core ML model."
      }
    }
  }

  private struct ModelMetadata: Codable {
    var featureVersion: Int
    var createdAt: Date
    var classes: [String]
    var sampleCount: Int
    var backends: [String]
  }
}
