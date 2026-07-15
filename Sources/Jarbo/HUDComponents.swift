import MapKit
import PDFKit
import SceneKit
import SwiftUI

struct ArcReactorView: View {
  let color: Color
  @State private var spin = false
  var body: some View {
    ZStack {
      ForEach(0..<5, id: \.self) { i in
        Circle().trim(from: CGFloat(i) * 0.11, to: CGFloat(i) * 0.11 + 0.16).stroke(
          color.opacity(0.35 + Double(i) * 0.12),
          style: StrokeStyle(lineWidth: CGFloat(2 + i), lineCap: .round)
        ).padding(CGFloat(i) * 13).rotationEffect(
          .degrees(spin ? Double(i % 2 == 0 ? 360 : -360) : 0))
      }.animation(.linear(duration: Double(5 + 1)).repeatForever(autoreverses: false), value: spin)
      Circle().fill(color.opacity(0.16)).padding(54).shadow(color: color, radius: 26)
      Circle().stroke(color, lineWidth: 2).padding(66)
      Text("J").font(.system(size: 30, weight: .black, design: .rounded)).foregroundStyle(color)
    }.onAppear { spin = true }
  }
}
struct HUDCard<Content: View>: View {
  let title: String
  let color: Color
  @ViewBuilder var content: Content
  @State private var offset = CGSize.zero
  @State private var position = CGSize.zero
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(title.uppercased()).font(.system(size: 10, weight: .black, design: .monospaced))
          .tracking(2)
        Spacer()
        Circle().fill(color).frame(width: 6, height: 6).shadow(color: color, radius: 5)
      }.foregroundStyle(color).contentShape(Rectangle()).gesture(
        DragGesture().onChanged {
          offset = CGSize(
            width: position.width + $0.translation.width,
            height: position.height + $0.translation.height)
        }.onEnded { _ in position = offset })
      content
    }.padding(13).background(.black.opacity(0.72)).overlay(
      RoundedRectangle(cornerRadius: 4).stroke(color.opacity(0.55))
    ).shadow(color: color.opacity(0.15), radius: 16).offset(offset)
  }
}
struct AudioVisualizerView: View {
  let color: Color
  @State private var phase = 0.0
  var body: some View {
    TimelineView(.animation) { timeline in
      HStack(alignment: .center, spacing: 3) {
        ForEach(0..<30, id: \.self) { i in
          RoundedRectangle(cornerRadius: 2).fill(color.gradient).frame(
            width: 3,
            height: 8 + abs(
              sin(timeline.date.timeIntervalSinceReferenceDate * 3 + Double(i) * 0.48)) * 42)
        }
      }
    }.frame(height: 54)
  }
}
struct SuitSceneView: NSViewRepresentable {
  func makeNSView(context: Context) -> SCNView {
    let v = SCNView()
    v.backgroundColor = .clear
    v.allowsCameraControl = true
    let scene = SCNScene()
    let body = SCNCapsule(capRadius: 0.55, height: 2.4)
    body.firstMaterial?.diffuse.contents = NSColor.darkGray
    body.firstMaterial?.emission.contents = NSColor.cyan.withAlphaComponent(0.15)
    let node = SCNNode(geometry: body)
    node.addChildNode(SCNNode(geometry: SCNSphere(radius: 0.18)))
    scene.rootNode.addChildNode(node)
    let light = SCNLight()
    light.type = .omni
    light.color = NSColor.cyan
    let l = SCNNode()
    l.light = light
    l.position = SCNVector3(2, 2, 3)
    scene.rootNode.addChildNode(l)
    let camera = SCNCamera()
    let c = SCNNode()
    c.camera = camera
    c.position = SCNVector3(0, 0, 5)
    scene.rootNode.addChildNode(c)
    v.scene = scene
    v.autoenablesDefaultLighting = true
    return v
  }
  func updateNSView(_ nsView: SCNView, context: Context) {}
}
struct PDFPreview: NSViewRepresentable {
  let url: URL
  func makeNSView(context: Context) -> PDFView {
    let v = PDFView()
    v.autoScales = true
    v.document = PDFDocument(url: url)
    return v
  }
  func updateNSView(_ nsView: PDFView, context: Context) { nsView.document = PDFDocument(url: url) }
}
struct MapPanel: View {
  @State private var position = MapCameraPosition.region(
    .init(
      center: .init(latitude: 37.7749, longitude: -122.4194),
      span: .init(latitudeDelta: 0.2, longitudeDelta: 0.2)))
  var body: some View {
    Map(position: $position).mapStyle(.hybrid(elevation: .realistic)).frame(minHeight: 180)
      .clipShape(RoundedRectangle(cornerRadius: 3))
  }
}
