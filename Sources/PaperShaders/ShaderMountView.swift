import MetalKit
import QuartzCore
#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// On-screen mount for a shader, mirroring the upstream `ShaderMount`:
/// full-screen quad, automatic `u_time`/`u_resolution`/`u_pixelRatio`
/// uniforms, deterministic `frame`/`speed` timing, background pause and
/// `minPixelRatio`/`maxPixelCount` resolution control.
public final class ShaderMountView: MTKView, MTKViewDelegate {
  private let renderer: ShaderRenderer

  /// Math mode used to compile the Metal pipeline.
  public let mathMode: ShaderMathMode

  /// Shader-specific uniform values, in the shader's declaration order.
  public var uniforms: [UniformValue] {
    didSet { redrawNow() }
  }

  /// Sizing.
  public var sizing: ShaderSizingParams {
    didSet { redrawNow() }
  }

  /// Minimum render scale relative to logical points (upstream default 2).
  public var minPixelRatio: Double = 2 {
    didSet {
      if minPixelRatio != oldValue {
        invalidateDrawableSize()
      }
    }
  }

  /// Maximum total rendered pixels (upstream default 1920×1080×4).
  public var maxPixelCount: Double = 1920 * 1080 * 4 {
    didSet {
      if maxPixelCount != oldValue {
        invalidateDrawableSize()
      }
    }
  }

  /// Target frame rate for adaptive quality. `nil` keeps the resolution fixed.
  public var adaptiveTargetFrameRate: Double? {
    didSet {
      if adaptiveTargetFrameRate != oldValue {
        resetAdaptiveQuality()
      }
    }
  }

  /// Lowest adaptive render scale relative to logical points.
  public var adaptiveMinimumPixelRatio: Double = 1 {
    didSet {
      if adaptiveMinimumPixelRatio != oldValue {
        invalidateDrawableSize()
      }
    }
  }

  /// Called from the main thread with throttled render metrics.
  public var onRenderMetricsChanged: ((ShaderRenderMetrics) -> Void)?

  /// Total animation time in milliseconds (`u_time` is this × 0.001).
  private var currentFrame: Double
  private var speed: Double
  private var lastRenderTime: Double?
  private var renderScale: Float = 1
  private var adaptiveResolutionScale: Double = 1
  private var smoothedFrameDuration: Double?
  private var lastAdaptiveQualityUpdate: Double = 0
  private var metricsWindowStart: Double?
  private var metricsFrameCount = 0
  private var lastMetricsUpdate = 0.0
  private var lastMetrics: ShaderRenderMetrics?
  private var wasPausedBeforeBackground = false

  /// Creates an instance.
  public init(
    descriptor: ShaderDescriptor,
    uniforms: [UniformValue] = [],
    sizing: ShaderSizingParams = .defaultPattern,
    speed: Double = 1,
    frame startFrame: Double = 0,
    device: MTLDevice? = nil,
    mathMode: ShaderMathMode = .precise
  ) throws {
    renderer = try ShaderRenderer(descriptor: descriptor, device: device, mathMode: mathMode)
    self.mathMode = mathMode
    self.uniforms = uniforms
    self.sizing = sizing
    self.speed = speed
    self.currentFrame = startFrame
    super.init(frame: .zero, device: renderer.device)
    colorPixelFormat = .bgra8Unorm
    clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
    autoResizeDrawable = false
    isPaused = false
    delegate = self
    observeAppState()
  }

  @available(*, unavailable)
  /// Creates an instance.
  public required init(coder: NSCoder) {
    fatalError("init(coder:) is not supported")
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  /// Get frame.
  public func getFrame() -> Double { currentFrame }

  /// Set frame.
  public func setFrame(_ newFrame: Double) {
    currentFrame = newFrame
    lastRenderTime = CACurrentMediaTime() * 1000
    redrawNow()
  }

  /// Get speed.
  public func getSpeed() -> Double { speed }

  /// Set speed.
  public func setSpeed(_ newSpeed: Double) {
    speed = newSpeed
    if newSpeed != 0 {
      lastRenderTime = CACurrentMediaTime() * 1000
      isPaused = false
    }
  }

  // MARK: - MTKViewDelegate

  /// Mtk view.
  public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

  /// Draw.
  public func draw(in view: MTKView) {
    let boundsSize = bounds.size
    guard boundsSize.width > 0, boundsSize.height > 0 else { return }
    updateDrawableSizeIfNeeded(boundsSize: boundsSize)

    let now = CACurrentMediaTime() * 1000
    let dt = now - (lastRenderTime ?? now)
    lastRenderTime = now
    if speed != 0 {
      currentFrame += dt * speed
    }

    guard let renderPassDescriptor = currentRenderPassDescriptor,
          let drawable = currentDrawable,
          let commandBuffer = renderer.commandQueue.makeCommandBuffer()
    else { return }

    renderer.encode(
      commandBuffer: commandBuffer,
      renderPassDescriptor: renderPassDescriptor,
      time: Float(currentFrame * 0.001),
      resolution: SIMD2(Float(drawableSize.width), Float(drawableSize.height)),
      pixelRatio: renderScale,
      sizing: sizing,
      uniforms: uniforms
    )
    commandBuffer.present(drawable)
    commandBuffer.commit()
    updateAdaptiveQuality(frameDuration: dt, now: now)
    updateRenderMetrics(frameDuration: dt, now: now)

    // Upstream stops the RAF loop entirely at speed 0.
    if speed == 0 {
      isPaused = true
    }
  }

  // MARK: - Resolution control (upstream handleResize)

  private func updateDrawableSizeIfNeeded(boundsSize: CGSize) {
    let dpr = max(1, displayScale)
    let scaleToMeetMinPixelRatio = max(1, minPixelRatio / dpr)
    let basePixelRatio = dpr * scaleToMeetMinPixelRatio
    let effectiveAdaptiveScale = effectiveAdaptiveResolutionScale(basePixelRatio: basePixelRatio)
    let targetPixelWidth = boundsSize.width * basePixelRatio * effectiveAdaptiveScale
    let targetPixelHeight = boundsSize.height * basePixelRatio * effectiveAdaptiveScale

    let maxPixelCountHeadroom = maxPixelCount.squareRoot()
      / Double(targetPixelWidth * targetPixelHeight).squareRoot()
    let scaleToMeetMaxPixelCount = min(1, maxPixelCountHeadroom)

    let newWidth = (targetPixelWidth * scaleToMeetMaxPixelCount).rounded()
    let newHeight = (targetPixelHeight * scaleToMeetMaxPixelCount).rounded()
    renderScale = Float(newWidth / boundsSize.width.rounded())

    let newSize = CGSize(width: newWidth, height: newHeight)
    if drawableSize != newSize {
      drawableSize = newSize
      lastMetrics = nil
    }
  }

  private func updateAdaptiveQuality(frameDuration: Double, now: Double) {
    guard let targetFrameRate = adaptiveTargetFrameRate, targetFrameRate > 0 else {
      return
    }
    guard frameDuration.isFinite, frameDuration > 0 else {
      return
    }

    let targetDuration = 1000 / targetFrameRate
    let previous = smoothedFrameDuration ?? frameDuration
    let smoothed = previous * 0.85 + frameDuration * 0.15
    smoothedFrameDuration = smoothed

    if smoothed > targetDuration * 1.12, now - lastAdaptiveQualityUpdate > 250 {
      setAdaptiveResolutionScale(adaptiveResolutionScale * 0.88, now: now)
    } else if smoothed < targetDuration * 0.72,
              adaptiveResolutionScale < 0.999,
              now - lastAdaptiveQualityUpdate > 900 {
      setAdaptiveResolutionScale(adaptiveResolutionScale * 1.08, now: now)
    }
  }

  private func setAdaptiveResolutionScale(_ scale: Double, now: Double) {
    let nextScale = min(1, max(0.1, scale))
    guard abs(nextScale - adaptiveResolutionScale) > 0.001 else {
      return
    }
    adaptiveResolutionScale = nextScale
    lastAdaptiveQualityUpdate = now
    invalidateDrawableSize(redraw: false)
  }

  private func resetAdaptiveQuality() {
    adaptiveResolutionScale = 1
    smoothedFrameDuration = nil
    lastAdaptiveQualityUpdate = 0
    invalidateDrawableSize()
  }

  private func invalidateDrawableSize(redraw: Bool = true) {
    drawableSize = .zero
    lastMetrics = nil
    if redraw {
      redrawNow()
    }
  }

  private func effectiveAdaptiveResolutionScale(basePixelRatio: Double? = nil) -> Double {
    let basePixelRatio = basePixelRatio ?? max(1, displayScale) * max(1, minPixelRatio / max(1, displayScale))
    let minimumAdaptiveScale = min(1, max(0.1, adaptiveMinimumPixelRatio / basePixelRatio))
    return min(1, max(minimumAdaptiveScale, adaptiveResolutionScale))
  }

  private func updateRenderMetrics(frameDuration: Double, now: Double) {
    metricsFrameCount += 1
    let windowStart = metricsWindowStart ?? now
    metricsWindowStart = windowStart
    let elapsed = now - windowStart
    let shouldReportImmediately = lastMetrics == nil
    let shouldReportWindow = elapsed >= 500
    guard shouldReportImmediately || shouldReportWindow else {
      return
    }

    let fps: Double
    if elapsed > 0 {
      fps = Double(metricsFrameCount) * 1000 / elapsed
    } else if frameDuration > 0 {
      fps = 1000 / frameDuration
    } else {
      fps = 0
    }

    let metrics = ShaderRenderMetrics(
      framesPerSecond: fps,
      frameDurationMilliseconds: max(0, frameDuration),
      drawablePixelWidth: Int(drawableSize.width.rounded()),
      drawablePixelHeight: Int(drawableSize.height.rounded()),
      displayScale: displayScale,
      renderScale: Double(renderScale),
      adaptiveResolutionScale: effectiveAdaptiveResolutionScale(),
      mathMode: mathMode
    )

    if shouldReportImmediately || now - lastMetricsUpdate >= 250 || metrics != lastMetrics {
      lastMetricsUpdate = now
      lastMetrics = metrics
      onRenderMetricsChanged?(metrics)
    }

    if shouldReportWindow {
      metricsWindowStart = now
      metricsFrameCount = 0
    }
  }

  private var displayScale: Double {
    #if os(iOS) || os(tvOS)
    let scale = traitCollection.displayScale
    return scale > 0 ? Double(scale) : 1
    #elseif os(macOS)
    return Double(window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1)
    #endif
  }

  // MARK: - Background pause

  private func redrawNow() {
    guard Thread.isMainThread else {
      DispatchQueue.main.async { [weak self] in
        self?.redrawNow()
      }
      return
    }
    // Slider tracking can temporarily starve the MTKView display link on
    // macOS; draw immediately so SwiftUI control updates reach Metal in the
    // same interaction pass.
    draw()
    // One frame will be rendered by the display link; draw(in:) re-pauses when
    // speed == 0.
    if isPaused {
      isPaused = false
    }
  }

  private func observeAppState() {
    #if os(iOS) || os(tvOS)
    NotificationCenter.default.addObserver(
      self, selector: #selector(appDidResignActive),
      name: UIApplication.didEnterBackgroundNotification, object: nil
    )
    NotificationCenter.default.addObserver(
      self, selector: #selector(appWillBecomeActive),
      name: UIApplication.willEnterForegroundNotification, object: nil
    )
    #elseif os(macOS)
    NotificationCenter.default.addObserver(
      self, selector: #selector(appDidResignActive),
      name: NSApplication.didHideNotification, object: nil
    )
    NotificationCenter.default.addObserver(
      self, selector: #selector(appWillBecomeActive),
      name: NSApplication.didUnhideNotification, object: nil
    )
    #endif
  }

  @objc private func appDidResignActive() {
    wasPausedBeforeBackground = isPaused
    isPaused = true
  }

  @objc private func appWillBecomeActive() {
    lastRenderTime = CACurrentMediaTime() * 1000
    isPaused = wasPausedBeforeBackground
  }
}
