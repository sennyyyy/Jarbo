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
          $0.features.count == self.featureCount && $0.gesture.category == .staticPose
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
        let sourceURL = directory.appending(path: "PersonalGestureClassifier.mlmodel")
        if FileManager.default.fileExists(atPath: sourceURL.path) {
          try FileManager.default.removeItem(at: sourceURL)
        }
        try classifier.write(to: sourceURL, metadata: nil)
        let compiled = try MLModel.compileModel(at: sourceURL)
        let destination = self.compiledModelURL
        if FileManager.default.fileExists(atPath: destination.path) {
          try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: compiled, to: destination)
        let loaded = try MLModel(contentsOf: destination, configuration: Self.configuration)
        self.lock.lock()
        self.model = loaded
        self.lock.unlock()
        completion(.success(usable.count))
      } catch {
        completion(.failure(error))
      }
    }
  }

  private func loadSavedModel() {
    guard FileManager.default.fileExists(atPath: compiledModelURL.path),
      let loaded = try? MLModel(contentsOf: compiledModelURL, configuration: Self.configuration)
    else { return }
    model = loaded
  }

  private var modelDirectory: URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appending(path: "Jarbo/Models", directoryHint: .isDirectory)
  }

  private var compiledModelURL: URL {
    modelDirectory.appending(path: "PersonalGestureClassifier.mlmodelc", directoryHint: .isDirectory)
  }

  private static let configuration: MLModelConfiguration = {
    let configuration = MLModelConfiguration()
    configuration.computeUnits = .all
    return configuration
  }()

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
}
