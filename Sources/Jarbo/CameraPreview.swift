import AVFoundation
import SwiftUI

struct CameraPreview: NSViewRepresentable {
  let session: AVCaptureSession
  func makeNSView(context: Context) -> NSView {
    let view = PreviewView()
    view.layer = AVCaptureVideoPreviewLayer(session: session)
    view.layer?.contentsGravity = .resizeAspectFill
    configure(view.layer as? AVCaptureVideoPreviewLayer)
    return view
  }
  func updateNSView(_ nsView: NSView, context: Context) {
    let layer = nsView.layer as? AVCaptureVideoPreviewLayer
    layer?.session = session
    configure(layer)
  }
  private func configure(_ layer: AVCaptureVideoPreviewLayer?) {
    layer?.videoGravity = .resizeAspectFill
    guard let connection = layer?.connection else { return }
    if connection.isVideoMirroringSupported {
      connection.automaticallyAdjustsVideoMirroring = false
      connection.isVideoMirrored = true
    }
    if connection.isVideoRotationAngleSupported(0) { connection.videoRotationAngle = 0 }
  }
  final class PreviewView: NSView {
    override func makeBackingLayer() -> CALayer { AVCaptureVideoPreviewLayer() }
  }
}
