import PaperShaders
import SwiftUI

/// Bridges `ShaderMountView` into SwiftUI on both platforms.
struct ShaderViewRepresentable {
  let descriptor: ShaderDescriptor
  let uniforms: [UniformValue]
  let sizing: ShaderSizingParams
  let speed: Double
  let frame: Double
  let renderOptions: ShaderRenderOptions
  let onRenderMetricsChanged: ((ShaderRenderMetrics) -> Void)?

  final class Coordinator {
    var mount: ShaderMountView?
    var lastFrameValue: Double = 0
  }

  func makeCoordinator() -> Coordinator { Coordinator() }

  private func makeMount(coordinator: Coordinator) -> ShaderMountView? {
    guard let mount = try? ShaderMountView(
      descriptor: descriptor,
      uniforms: uniforms,
      sizing: sizing,
      speed: speed,
      frame: frame,
      mathMode: renderOptions.mathMode
    ) else {
      return nil
    }
    applyRenderOptions(to: mount)
    mount.onRenderMetricsChanged = onRenderMetricsChanged
    coordinator.mount = mount
    coordinator.lastFrameValue = frame
    return mount
  }

  private func update(coordinator: Coordinator) {
    guard let mount = coordinator.mount else { return }
    if mount.uniforms != uniforms {
      mount.uniforms = uniforms
    }
    if mount.sizing != sizing {
      mount.sizing = sizing
    }
    applyRenderOptions(to: mount)
    mount.onRenderMetricsChanged = onRenderMetricsChanged
    if mount.getSpeed() != speed {
      mount.setSpeed(speed)
    }
    // Only reset the animation clock when the frame value itself changes —
    // the mount's own frame advances continuously while animating.
    if coordinator.lastFrameValue != frame {
      coordinator.lastFrameValue = frame
      mount.setFrame(frame)
    }
  }

  private func applyRenderOptions(to mount: ShaderMountView) {
    if mount.minPixelRatio != renderOptions.minPixelRatio {
      mount.minPixelRatio = renderOptions.minPixelRatio
    }
    if mount.maxPixelCount != renderOptions.maxPixelCount {
      mount.maxPixelCount = renderOptions.maxPixelCount
    }
    if mount.adaptiveTargetFrameRate != renderOptions.adaptiveTargetFrameRate {
      mount.adaptiveTargetFrameRate = renderOptions.adaptiveTargetFrameRate
    }
    if mount.adaptiveMinimumPixelRatio != renderOptions.adaptiveMinimumPixelRatio {
      mount.adaptiveMinimumPixelRatio = renderOptions.adaptiveMinimumPixelRatio
    }
  }
}

#if os(macOS)
extension ShaderViewRepresentable: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView {
    let container = NSView(frame: .zero)
    if let mount = makeMount(coordinator: context.coordinator) {
      mount.frame = container.bounds
      mount.autoresizingMask = [.width, .height]
      container.addSubview(mount)
    }
    return container
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    update(coordinator: context.coordinator)
  }
}
#else
extension ShaderViewRepresentable: UIViewRepresentable {
  func makeUIView(context: Context) -> UIView {
    let container = UIView(frame: .zero)
    if let mount = makeMount(coordinator: context.coordinator) {
      mount.frame = container.bounds
      mount.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      container.addSubview(mount)
    }
    return container
  }

  func updateUIView(_ uiView: UIView, context: Context) {
    update(coordinator: context.coordinator)
  }
}
#endif
