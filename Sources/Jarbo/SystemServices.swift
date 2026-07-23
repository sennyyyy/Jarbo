@preconcurrency import AVFoundation
import AppKit
import Foundation
import IOKit.ps
@preconcurrency import Speech
import Vision

@MainActor final class SystemMonitor: ObservableObject {
  @Published var battery = 0
  @Published var charging = false
  @Published var memory = "—"
  @Published var uptime = "—"
  @Published var now = Date()
  private var timer: Timer?
  init() {
    refresh()
    timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
      Task { @MainActor in self?.refresh() }
    }
  }
  private func refresh() {
    now = Date()
    let info = ProcessInfo.processInfo
    uptime = Duration.seconds(info.systemUptime).formatted(
      .units(allowed: [.hours, .minutes], width: .abbreviated))
    let used = Double(info.physicalMemory) / 1_073_741_824
    memory = String(format: "%0.0f GB", used)
    if let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
      let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
      let source = list.first,
      let d = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any]
    {
      battery = d[kIOPSCurrentCapacityKey] as? Int ?? 0
      charging = (d[kIOPSIsChargingKey] as? Bool) ?? false
    }
  }
}

@MainActor final class VoiceService: NSObject, ObservableObject {
  @Published var listening = false
  @Published var transcript = ""
  private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
  private let engine = AVAudioEngine()
  private var request: SFSpeechAudioBufferRecognitionRequest?
  private var task: SFSpeechRecognitionTask?
  var onCommand: ((String) -> Void)?
  func toggle() { listening ? stop() : start() }
  func start() {
    SFSpeechRecognizer.requestAuthorization { [weak self] status in
      guard status == .authorized else { return }
      Task { @MainActor [weak self] in self?.begin() }
    }
  }
  private func begin() {
    request = SFSpeechAudioBufferRecognitionRequest()
    guard let request else { return }
    request.shouldReportPartialResults = true
    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    input.removeTap(onBus: 0)
    input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
      request.append(buffer)
    }
    engine.prepare()
    try? engine.start()
    listening = true
    task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
      let text = result?.bestTranscription.formattedString
      let isFinal = result?.isFinal ?? false
      let failed = error != nil
      Task { @MainActor [weak self] in
        guard let self else { return }
        if let text { self.transcript = text }
        if isFinal {
          self.onCommand?(self.transcript.lowercased())
          self.stop()
        } else if failed {
          self.stop()
        }
      }
    }
  }
  func stop() {
    engine.stop()
    engine.inputNode.removeTap(onBus: 0)
    request?.endAudio()
    task?.cancel()
    listening = false
  }
}

@MainActor final class ImageAnalyzer: ObservableObject {
  @Published var summary = "Drop an image here to analyze it on-device."
  func analyze(_ url: URL) {
    guard let image = NSImage(contentsOf: url),
      let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    else { return }
    let request = VNClassifyImageRequest { [weak self] request, _ in
      let labels =
        (request.results as? [VNClassificationObservation])?.prefix(5).map {
          "\($0.identifier) \(Int($0.confidence*100))%"
        }.joined(separator: " · ") ?? "No objects recognized"
      DispatchQueue.main.async { self?.summary = labels }
    }
    try? VNImageRequestHandler(cgImage: cg).perform([request])
  }
}

@MainActor final class ImageGenerationService: ObservableObject {
  @Published var apiKey = ""
  @Published var prompt = ""
  @Published var status = "Optional OpenAI API key required"
  @Published var image: NSImage?
  func generate() {
    guard !apiKey.isEmpty, !prompt.isEmpty else {
      status = "Enter an API key and prompt"
      return
    }
    status = "Generating…"
    var request = URLRequest(url: URL(string: "https://api.openai.com/v1/images/generations")!)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try? JSONSerialization.data(withJSONObject: [
      "model": "gpt-image-1", "prompt": prompt, "size": "1024x1024", "quality": "medium",
    ])
    URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
      guard let self else { return }
      DispatchQueue.main.async {
        if let error {
          self.status = error.localizedDescription
          return
        }
        guard let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let entries = json["data"] as? [[String: Any]],
          let b64 = entries.first?["b64_json"] as? String, let bytes = Data(base64Encoded: b64),
          let image = NSImage(data: bytes)
        else {
          self.status = "Generation failed—check your key"
          return
        }
        self.image = image
        self.status = "Image ready"
      }
    }
    .resume()
  }
}
