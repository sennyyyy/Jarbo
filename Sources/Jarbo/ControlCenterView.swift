import AppKit
import SwiftUI
import Vision

struct ControlCenterView: View {
  @EnvironmentObject var state: AppState
  @EnvironmentObject var tracker: HandTrackingService
  @EnvironmentObject var automation: AutomationService
  @EnvironmentObject var monitor: SystemMonitor
  @EnvironmentObject var voice: VoiceService
  @EnvironmentObject var analyzer: ImageAnalyzer
  @EnvironmentObject var imageGen: ImageGenerationService
  @State private var showBindings = false
  @State private var showImageGen = false
  @State private var showExtras = false
  private var accent: Color { state.theme.accent }

  var body: some View {
    ZStack {
      state.theme.background.ignoresSafeArea()
      GridPattern(color: accent).opacity(0.14)
      if state.showHUD { hud.transition(.opacity.combined(with: .scale(scale: 0.97))) }
      if !state.launchComplete { LaunchIntro(color: accent).transition(.opacity).zIndex(5) }
    }
    .preferredColorScheme(.dark)
    .onAppear {
      automation.refreshAccessibility()
      tracker.start()
      withAnimation(.easeOut(duration: 0.8).delay(1.7)) { state.launchComplete = true }
    }
    .onReceive(NotificationCenter.default.publisher(for: .jarboGenerateImage)) { note in
      imageGen.prompt = note.object as? String ?? ""
      showImageGen = true
    }
    .sheet(isPresented: $showBindings) { BindingsEditor() }
    .sheet(isPresented: $showImageGen) { ImageGeneratorView() }
    .sheet(isPresented: $showExtras) { ExtraWidgetsView() }
  }

  private var hud: some View {
    VStack(spacing: 0) {
      topBar
      if !automation.accessibilityGranted { accessBanner }
      GeometryReader { geo in
        ZStack {
          ArcReactorView(color: accent)
            .frame(width: min(geo.size.width * 0.34, 420), height: min(geo.size.width * 0.34, 420))
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
          cameraCard.position(x: 225, y: 185)
          systemCard.position(x: geo.size.width - 160, y: 135)
          commandCard.position(x: geo.size.width - 190, y: 330)
          notesCard.position(x: 220, y: geo.size.height - 125)
          musicCard.position(x: geo.size.width - 210, y: geo.size.height - 110)
          if let url = state.selectedViewerURL {
            viewerCard(url).position(x: geo.size.width / 2, y: geo.size.height / 2)
          }
        }
      }
    }
  }

  private var topBar: some View {
    HStack(spacing: 16) {
      Image(systemName: "circle.hexagongrid.fill").font(.title2)
      VStack(alignment: .leading, spacing: 1) {
        Text("JARBO").font(.system(size: 17, weight: .black, design: .rounded)).tracking(5)
        Text("MACBOOK AUTOMATION CORE").font(.system(size: 8, weight: .bold, design: .monospaced))
          .tracking(2).foregroundStyle(.secondary)
      }
      Spacer()
      Picker("Theme", selection: $state.theme) {
        ForEach(JarboTheme.allCases) { Text($0.rawValue).tag($0) }
      }.frame(width: 150)
      Button {
        voice.toggle()
      } label: {
        Label(
          voice.listening ? "LISTENING" : "VOICE", systemImage: voice.listening ? "waveform" : "mic"
        )
      }
      Button("ACTIONS") { showBindings = true }
      Button {
        automation.requestAccessibility()
      } label: {
        Label(
          automation.accessibilityGranted ? "CONTROL READY" : "ENABLE CONTROL",
          systemImage: automation.accessibilityGranted
            ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
      }.tint(automation.accessibilityGranted ? .green : .red)
      Button("GENERATE") { showImageGen = true }
      Button("WIDGETS") { showExtras = true }
      Circle().fill(tracker.running ? .green : .red).frame(width: 8, height: 8)
      Text(monitor.now.formatted(date: .omitted, time: .standard)).monospacedDigit()
    }
    .buttonStyle(.bordered).tint(accent).padding(.horizontal, 18).frame(height: 62)
    .background(.black.opacity(0.72))
    .overlay(alignment: .bottom) { Rectangle().fill(accent.opacity(0.5)).frame(height: 1) }
  }

  private var accessBanner: some View {
    HStack(spacing: 12) {
      Image(systemName: "cursorarrow.rays").foregroundStyle(.red)
      Text("MAC CONTROL IS BLOCKED UNTIL ACCESSIBILITY IS ENABLED")
        .font(.system(size: 10, weight: .black, design: .monospaced)).tracking(1.2)
      Spacer()
      Button("OPEN ACCESSIBILITY SETTINGS") { automation.requestAccessibility() }
        .buttonStyle(.borderedProminent).tint(.red)
    }.padding(.horizontal, 18).frame(height: 42).background(.red.opacity(0.13))
  }

  private var cameraCard: some View {
    HUDCard(title: "Neural hand-control feed", color: .green) {
      ZStack {
        CameraPreview(session: tracker.session).frame(width: 390, height: 219).clipShape(
          RoundedRectangle(cornerRadius: 7))
        LinearGradient(
          colors: [.clear, .black.opacity(0.42)], startPoint: .center, endPoint: .bottom
        ).clipShape(RoundedRectangle(cornerRadius: 7))
        ForEach(tracker.hands) { hand in
          HandOverlay(
            hand: hand,
            role: hand.id == .left ? state.leftRole : state.rightRole,
            bindings: state.bindings)
        }
        if tracker.hands.isEmpty {
          VStack(spacing: 8) {
            Image(systemName: "hand.raised.slash").font(.title2)
            Text(tracker.running ? "SHOW YOUR HANDS" : "CAMERA OFFLINE")
              .font(.caption.bold().monospaced()).tracking(1.4)
          }.foregroundStyle(.white.opacity(0.72))
        }
      }
      HStack {
        Label("\(tracker.hands.count)/2 TRACKED", systemImage: "viewfinder")
          .foregroundStyle(tracker.hands.isEmpty ? Color.secondary : Color.green)
        Spacer()
        Text("L = YOUR LEFT  ·  R = YOUR RIGHT").foregroundStyle(.secondary)
        Spacer()
        Text(tracker.running ? "● LIVE" : "○ OFFLINE")
          .foregroundStyle(tracker.running ? .green : .red)
      }
      .font(.system(size: 8, weight: .bold, design: .monospaced))
      Text(automation.lastOutput).font(.system(size: 9, weight: .black, design: .monospaced))
        .foregroundStyle(automation.accessibilityGranted ? .green : .red)
        .frame(maxWidth: .infinity, alignment: .leading)
    }.frame(width: 390)
  }
  private var systemCard: some View {
    HUDCard(title: "System status", color: accent) { StatusPanel() }.frame(width: 270)
  }
  private var commandCard: some View {
    HUDCard(title: "Command log", color: accent) {
      ScrollView {
        VStack(alignment: .leading, spacing: 5) {
          ForEach(Array(state.commandLog.enumerated()), id: \.offset) { _, line in
            Text(line).font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
      }.frame(height: 120)
    }.frame(width: 330)
  }
  private var notesCard: some View {
    HUDCard(title: "Notes", color: accent) {
      TextEditor(text: $state.notes).scrollContentBackground(.hidden).font(
        .system(size: 12, design: .monospaced)
      ).frame(height: 100)
      HStack {
        Button("OPEN PDF / IMAGE", action: openViewer)
        Spacer()
        Button("ANALYZE IMAGE", action: analyzeImage)
      }
    }.frame(width: 360)
  }
  private var musicCard: some View {
    HUDCard(title: "Audio + music", color: accent) {
      AudioVisualizerView(color: accent)
      HStack {
        Button("◀︎") { quick(.previousTrack) }
        Button("▶︎ / Ⅱ") { quick(.playPause) }
        Button("▶︎") { quick(.nextTrack) }
        Spacer()
        Button("−") { quick(.volumeDown) }
        Button("+") { quick(.volumeUp) }
      }.buttonStyle(.borderless)
    }.frame(width: 360)
  }
  private func viewerCard(_ url: URL) -> some View {
    HUDCard(title: url.lastPathComponent, color: accent) {
      if url.pathExtension.lowercased() == "pdf" {
        PDFPreview(url: url)
      } else if let image = NSImage(contentsOf: url) {
        Image(nsImage: image).resizable().scaledToFit()
      }
    }.frame(width: 410, height: 310)
  }
  private func quick(_ kind: ActionKind) {
    automation.execute(.init(name: kind.rawValue, hand: .right, gesture: .fist, action: kind))
  }
  private func openViewer() {
    let p = NSOpenPanel()
    p.allowedContentTypes = [.pdf, .image]
    if p.runModal() == .OK { state.selectedViewerURL = p.url }
  }
  private func analyzeImage() {
    let p = NSOpenPanel()
    p.allowedContentTypes = [.image]
    if p.runModal() == .OK, let url = p.url {
      analyzer.analyze(url)
      state.notes = "IMAGE ANALYSIS\n\(analyzer.summary)"
    }
  }
}

struct ExtraWidgetsView: View {
  var body: some View {
    HStack(spacing: 18) {
      VStack(alignment: .leading) {
        Text("3D SUIT VIEWER").font(.headline.monospaced())
        SuitSceneView().frame(width: 390, height: 440)
        Text("Drag to orbit · scroll to zoom").font(.caption).foregroundStyle(.secondary)
      }
      VStack(alignment: .leading) {
        Text("MAP DISPLAY").font(.headline.monospaced())
        MapPanel().frame(width: 520, height: 440)
        Text("Location access is optional; the map remains usable without it.").font(.caption)
          .foregroundStyle(.secondary)
      }
    }.padding(22).frame(minWidth: 970, minHeight: 520).preferredColorScheme(.dark)
  }
}

struct HandOverlay: View {
  let hand: TrackedHand
  let role: HandRole
  let bindings: [ActionBinding]
  private let color = Color.green
  private let bones:
    [(VNHumanHandPoseObservation.JointName, VNHumanHandPoseObservation.JointName)] = [
      (.wrist, .thumbCMC), (.thumbCMC, .thumbMP), (.thumbMP, .thumbIP), (.thumbIP, .thumbTip),
      (.wrist, .indexMCP), (.indexMCP, .indexPIP), (.indexPIP, .indexDIP), (.indexDIP, .indexTip),
      (.wrist, .middleMCP), (.middleMCP, .middlePIP), (.middlePIP, .middleDIP),
      (.middleDIP, .middleTip), (.wrist, .ringMCP), (.ringMCP, .ringPIP),
      (.ringPIP, .ringDIP), (.ringDIP, .ringTip), (.wrist, .littleMCP),
      (.littleMCP, .littlePIP), (.littlePIP, .littleDIP), (.littleDIP, .littleTip),
      (.indexMCP, .middleMCP), (.middleMCP, .ringMCP), (.ringMCP, .littleMCP),
    ]
  var body: some View {
    GeometryReader { geo in
      let box = boundingBox(in: geo.size)
      ZStack {
        Path { path in
          for bone in bones {
            guard let a = hand.points[bone.0], let b = hand.points[bone.1] else { continue }
            path.move(to: CGPoint(x: a.x * geo.size.width, y: a.y * geo.size.height))
            path.addLine(to: CGPoint(x: b.x * geo.size.width, y: b.y * geo.size.height))
          }
        }.stroke(color.opacity(0.82), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        ForEach(Array(hand.points.keys), id: \.self) { key in
          if let p = hand.points[key] {
            Circle().fill(.black).frame(width: 7, height: 7).overlay(
              Circle().stroke(color, lineWidth: 1.5)
            ).position(x: p.x * geo.size.width, y: p.y * geo.size.height)
          }
        }
        RoundedRectangle(cornerRadius: 5).stroke(
          color, style: StrokeStyle(lineWidth: 2, dash: [9, 3])
        ).frame(width: box.width, height: box.height).position(x: box.midX, y: box.midY)
          .shadow(color: color, radius: 5)
        VStack(alignment: .leading, spacing: 2) {
          Text("\(hand.id == .left ? "L" : "R") · YOUR \(hand.id.rawValue.uppercased()) HAND")
            .font(.system(size: 9, weight: .black, design: .monospaced))
          Text(actionText).font(.system(size: 8, weight: .bold, design: .monospaced))
        }.padding(.horizontal, 7).padding(.vertical, 5).background(color).foregroundStyle(.black)
          .clipShape(RoundedRectangle(cornerRadius: 3)).position(
            x: min(max(box.minX + 75, 78), geo.size.width - 78), y: max(box.minY - 14, 16))
      }
    }
  }
  private var actionText: String {
    if role == .disabled { return "DISABLED" }
    if role == .pointer, hand.gesture == .point { return "POINT · MOVING CURSOR" }
    if let match = bindings.first(where: {
      $0.enabled && $0.hand == hand.id && $0.gesture == hand.gesture
    }) {
      return "\(hand.gesture.rawValue.uppercased()) · \(match.action.rawValue.uppercased())"
    }
    return "DETECTED · \(hand.gesture.rawValue.uppercased())"
  }
  private func boundingBox(in size: CGSize) -> CGRect {
    let values = Array(hand.points.values)
    guard let minX = values.map(\.x).min(), let maxX = values.map(\.x).max(),
      let minY = values.map(\.y).min(), let maxY = values.map(\.y).max()
    else { return CGRect(x: 8, y: 8, width: 80, height: 80) }
    let padding: CGFloat = 14
    let x = max(2, minX * size.width - padding)
    let y = max(2, minY * size.height - padding)
    let right = min(size.width - 2, maxX * size.width + padding)
    let bottom = min(size.height - 2, maxY * size.height + padding)
    return CGRect(x: x, y: y, width: max(44, right - x), height: max(54, bottom - y))
  }
}
struct StatusPanel: View {
  @EnvironmentObject var monitor: SystemMonitor
  var body: some View {
    VStack(spacing: 12) {
      Metric(
        label: "BATTERY", value: "\(monitor.battery)%",
        icon: monitor.charging ? "bolt.fill" : "battery.75percent")
      Metric(label: "MEMORY", value: monitor.memory, icon: "memorychip")
      Metric(label: "UPTIME", value: monitor.uptime, icon: "clock.arrow.circlepath")
      Metric(label: "NETWORK", value: "ONLINE", icon: "network")
    }
  }
}
struct Metric: View {
  let label: String
  let value: String
  let icon: String
  var body: some View {
    HStack {
      Image(systemName: icon).frame(width: 20)
      Text(label).font(.caption2.monospaced()).foregroundStyle(.secondary)
      Spacer()
      Text(value).font(.caption.bold().monospaced())
    }
  }
}
struct GridPattern: View {
  let color: Color
  var body: some View {
    Canvas { ctx, size in
      var path = Path()
      stride(from: 0.0, through: size.width, by: 40).forEach { x in
        path.move(to: .init(x: x, y: 0))
        path.addLine(to: .init(x: x, y: size.height))
      }
      stride(from: 0.0, through: size.height, by: 40).forEach { y in
        path.move(to: .init(x: 0, y: y))
        path.addLine(to: .init(x: size.width, y: y))
      }
      ctx.stroke(path, with: .color(color), lineWidth: 0.5)
    }
  }
}
struct LaunchIntro: View {
  let color: Color
  @State private var scale = 0.2
  @State private var opacity = 0.0
  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      ArcReactorView(color: color).frame(width: 260, height: 260).scaleEffect(scale)
      VStack {
        Spacer()
        Text("JARBO").font(.system(size: 34, weight: .black, design: .rounded)).tracking(12)
        Text("INITIALIZING NATIVE SYSTEMS").font(.caption.monospaced()).foregroundStyle(color)
        Spacer().frame(height: 100)
      }.opacity(opacity)
    }.onAppear {
      withAnimation(.spring(response: 1.2, dampingFraction: 0.65)) { scale = 1 }
      withAnimation(.easeIn(duration: 0.6).delay(0.7)) { opacity = 1 }
    }
  }
}

struct BindingsEditor: View {
  @EnvironmentObject var state: AppState
  @EnvironmentObject var tracker: HandTrackingService
  @EnvironmentObject var automation: AutomationService
  @State private var captureHand = HandSide.right
  @State private var trainingGesture = GestureKind.fist
  @State private var draft = ActionBinding(
    name: "New command", hand: .right, gesture: .openPalm, action: .missionControl)
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("PROGRAM HAND CONTROLS").font(.title2.bold()).tracking(2)
      HStack {
        Picker("Left hand", selection: $state.leftRole) {
          ForEach(HandRole.allCases) { Text($0.rawValue).tag($0) }
        }
        Picker("Right hand", selection: $state.rightRole) {
          ForEach(HandRole.allCases) { Text($0.rawValue).tag($0) }
        }
      }
      HStack(spacing: 12) {
        Label("Pointer sensitivity", systemImage: "cursorarrow.motionlines")
        Slider(value: $state.pointerSensitivity, in: 0.15...1.2, step: 0.05)
        Text("\(state.pointerSensitivity, specifier: "%.2f")×").monospacedDigit().frame(width: 54)
        Text("Relative mode: lift or close the hand to clutch and reposition.")
          .font(.caption).foregroundStyle(.secondary)
      }
      HStack(spacing: 10) {
        Text("PERSONAL TRAINING").font(.caption.bold()).tracking(1.2)
        Picker("Capture hand", selection: $captureHand) {
          Text("Left hand").tag(HandSide.left)
          Text("Right hand").tag(HandSide.right)
        }.frame(width: 160)
        Picker("Gesture", selection: $trainingGesture) {
          ForEach(GestureKind.allCases.filter { ![.swipeLeft, .swipeRight].contains($0) }) {
            Text($0.rawValue).tag($0)
          }
        }.frame(width: 155)
        Button("ADD SAMPLE · \(state.sampleCount(for: trainingGesture))/8") {
          if let features = tracker.captureTemplate(for: trainingGesture, hand: captureHand) {
            state.addTrainingSample(features, for: trainingGesture)
          } else {
            state.log("TRAINING FAILED — SHOW THE SELECTED HAND TO THE CAMERA")
          }
        }.buttonStyle(.borderedProminent)
        Button("CLEAR") { state.removeTemplate(for: trainingGesture) }
          .disabled(state.sampleCount(for: trainingGesture) == 0)
        Text("Add 3–5 natural variations of your fist, pinch, or custom pose.")
          .font(.caption).foregroundStyle(.secondary)
      }
      List {
        ForEach($state.bindings) { $binding in
          HStack {
            Toggle("", isOn: $binding.enabled).labelsHidden()
            TextField("Name", text: $binding.name)
            Picker("Hand", selection: $binding.hand) {
              Text("Left").tag(HandSide.left)
              Text("Right").tag(HandSide.right)
            }.frame(width: 90)
            Picker("Gesture", selection: $binding.gesture) {
              ForEach(GestureKind.allCases) { Text($0.rawValue).tag($0) }
            }.frame(width: 130)
            Picker("Action", selection: $binding.action) {
              ForEach(ActionKind.allCases) { Text($0.rawValue).tag($0) }
            }.frame(width: 150)
            TextField("Value / URL / command", text: $binding.value)
            Button(role: .destructive) {
              state.bindings.removeAll { $0.id == binding.id }
            } label: {
              Image(systemName: "trash")
            }
          }
        }
      }.frame(minHeight: 340)
      HStack {
        TextField("Name", text: $draft.name)
        Picker("Hand", selection: $draft.hand) {
          Text("Left").tag(HandSide.left)
          Text("Right").tag(HandSide.right)
        }
        Picker("Gesture", selection: $draft.gesture) {
          ForEach(GestureKind.allCases) { Text($0.rawValue).tag($0) }
        }
        Picker("Action", selection: $draft.action) {
          ForEach(ActionKind.allCases) { Text($0.rawValue).tag($0) }
        }
        TextField("Value", text: $draft.value)
        Button("ADD") {
          state.bindings.append(draft)
          draft = .init(
            name: "New command", hand: .right, gesture: .openPalm, action: .missionControl)
        }
      }
      HStack {
        Button("RESTORE ESSENTIAL PRESETS") { state.restoreEssentialControls() }
          .buttonStyle(.borderedProminent)
        Text("Restores precision left-hand pointer/clicks and non-conflicting right-hand controls.")
          .font(.caption).foregroundStyle(.secondary)
        Spacer()
        Button("TEST LEFT CLICK") {
          automation.execute(
            .init(name: "Test click", hand: .left, gesture: .pinch, action: .leftClick))
        }
        Button("TEST DESKTOP LEFT") {
          automation.execute(
            .init(name: "Test desktop", hand: .right, gesture: .swipeRight, action: .spaceLeft))
        }
        Button("TEST DESKTOP RIGHT") {
          automation.execute(
            .init(name: "Test desktop", hand: .right, gesture: .swipeLeft, action: .spaceRight))
        }
      }
      Text(
        "Shell commands and Accessibility actions run only when you explicitly bind and trigger them."
      ).font(.caption).foregroundStyle(.secondary)
    }.padding(22).frame(minWidth: 1050, minHeight: 500)
  }
}

struct ImageGeneratorView: View {
  @EnvironmentObject var service: ImageGenerationService
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("GENERATE IMAGE").font(.title2.bold())
      SecureField("OpenAI API key (kept in memory only)", text: $service.apiKey)
      TextField("Describe the image", text: $service.prompt, axis: .vertical).lineLimit(3...6)
      Button("GENERATE WITH GPT IMAGE") { service.generate() }.buttonStyle(.borderedProminent)
      Text(service.status).foregroundStyle(.secondary)
      if let image = service.image {
        Image(nsImage: image).resizable().scaledToFit().frame(maxHeight: 420)
        Button("SAVE IMAGE") {
          let panel = NSSavePanel()
          panel.allowedContentTypes = [.png]
          panel.nameFieldStringValue = "jarbo-image.png"
          if panel.runModal() == .OK, let url = panel.url, let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let data = bitmap.representation(using: .png, properties: [:])
          {
            try? data.write(to: url)
          }
        }
      }
    }.padding(24).frame(width: 620).frame(minHeight: 260)
  }
}
