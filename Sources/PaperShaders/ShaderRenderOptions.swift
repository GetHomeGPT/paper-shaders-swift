/// Math mode used when compiling an interactive Metal shader pipeline.
public enum ShaderMathMode: String, Equatable, Sendable {
  /// Prioritizes parity with the reference renderer and golden images.
  case precise

  /// Allows Metal fast-math optimizations for smoother interactive previews.
  case fast
}

/// Runtime rendering options for on-screen shader views.
public struct ShaderRenderOptions: Equatable, Sendable {
  /// Minimum render scale relative to logical points.
  public var minPixelRatio: Double

  /// Maximum total rendered pixels.
  public var maxPixelCount: Double

  /// Target frame rate for adaptive resolution. `nil` keeps resolution fixed.
  public var adaptiveTargetFrameRate: Double?

  /// Lowest adaptive render scale relative to logical points.
  public var adaptiveMinimumPixelRatio: Double

  /// Shader compiler math mode.
  public var mathMode: ShaderMathMode

  /// Creates render options.
  public init(
    minPixelRatio: Double = 2,
    maxPixelCount: Double = 1920 * 1080 * 4,
    adaptiveTargetFrameRate: Double? = nil,
    adaptiveMinimumPixelRatio: Double = 1,
    mathMode: ShaderMathMode = .precise
  ) {
    self.minPixelRatio = minPixelRatio
    self.maxPixelCount = maxPixelCount
    self.adaptiveTargetFrameRate = adaptiveTargetFrameRate
    self.adaptiveMinimumPixelRatio = adaptiveMinimumPixelRatio
    self.mathMode = mathMode
  }

  /// Fixed quality, matching the upstream pixel-ratio cap behavior.
  public static let fixed = ShaderRenderOptions()

  /// Fixed quality with faster math for interactive previews.
  public static let interactive = ShaderRenderOptions(mathMode: .fast)

  /// Adaptive quality that lowers internal resolution when rendering misses the target frame rate.
  public static func adaptive(
    targetFrameRate: Double = 60,
    minPixelRatio: Double = 2,
    adaptiveMinimumPixelRatio: Double = 1,
    maxPixelCount: Double = 1920 * 1080 * 4,
    mathMode: ShaderMathMode = .fast
  ) -> ShaderRenderOptions {
    ShaderRenderOptions(
      minPixelRatio: minPixelRatio,
      maxPixelCount: maxPixelCount,
      adaptiveTargetFrameRate: targetFrameRate,
      adaptiveMinimumPixelRatio: adaptiveMinimumPixelRatio,
      mathMode: mathMode
    )
  }
}
