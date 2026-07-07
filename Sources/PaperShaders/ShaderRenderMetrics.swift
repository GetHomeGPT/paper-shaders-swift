/// Lightweight runtime metrics reported by an on-screen shader mount.
public struct ShaderRenderMetrics: Equatable, Sendable {
  /// Estimated presentation rate for the last reporting window.
  public var framesPerSecond: Double

  /// Last observed frame duration in milliseconds.
  public var frameDurationMilliseconds: Double

  /// Current Metal drawable width in physical pixels.
  public var drawablePixelWidth: Int

  /// Current Metal drawable height in physical pixels.
  public var drawablePixelHeight: Int

  /// Platform display scale used before shader-specific caps are applied.
  public var displayScale: Double

  /// Effective shader pixel ratio passed to `u_pixelRatio`.
  public var renderScale: Double

  /// Adaptive resolution multiplier, or `1` when adaptive quality is not reducing resolution.
  public var adaptiveResolutionScale: Double

  /// Math mode used by the compiled Metal pipeline.
  public var mathMode: ShaderMathMode

  /// Creates metrics.
  public init(
    framesPerSecond: Double = 0,
    frameDurationMilliseconds: Double = 0,
    drawablePixelWidth: Int = 0,
    drawablePixelHeight: Int = 0,
    displayScale: Double = 1,
    renderScale: Double = 1,
    adaptiveResolutionScale: Double = 1,
    mathMode: ShaderMathMode = .precise
  ) {
    self.framesPerSecond = framesPerSecond
    self.frameDurationMilliseconds = frameDurationMilliseconds
    self.drawablePixelWidth = drawablePixelWidth
    self.drawablePixelHeight = drawablePixelHeight
    self.displayScale = displayScale
    self.renderScale = renderScale
    self.adaptiveResolutionScale = adaptiveResolutionScale
    self.mathMode = mathMode
  }

  /// Empty metrics before the first drawable is rendered.
  public static let empty = ShaderRenderMetrics()
}
