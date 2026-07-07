/// Port of upstream `shader-sizing.ts`.
public enum ShaderFit: String, Equatable, Sendable {
  case none
  case contain
  case cover

  /// Value passed to the `u_fit` uniform (upstream `ShaderFitOptions`).
  public var uniformValue: Float {
    switch self {
    case .none: return 0
    case .contain: return 1
    case .cover: return 2
    }
  }
}

/// Shader sizing params.
public struct ShaderSizingParams: Equatable, Sendable {
  /// Fit.
  public var fit: ShaderFit
  /// Scale.
  public var scale: Float
  /// Rotation.
  public var rotation: Float
  /// Origin x.
  public var originX: Float
  /// Origin y.
  public var originY: Float
  /// Offset x.
  public var offsetX: Float
  /// Offset y.
  public var offsetY: Float
  /// World width.
  public var worldWidth: Float
  /// World height.
  public var worldHeight: Float

  /// Creates an instance.
  public init(
    fit: ShaderFit,
    scale: Float = 1,
    rotation: Float = 0,
    originX: Float = 0.5,
    originY: Float = 0.5,
    offsetX: Float = 0,
    offsetY: Float = 0,
    worldWidth: Float = 0,
    worldHeight: Float = 0
  ) {
    self.fit = fit
    self.scale = scale
    self.rotation = rotation
    self.originX = originX
    self.originY = originY
    self.offsetX = offsetX
    self.offsetY = offsetY
    self.worldWidth = worldWidth
    self.worldHeight = worldHeight
  }

  /// Upstream `defaultObjectSizing` (gradients and object-like shaders).
  public static let defaultObject = ShaderSizingParams(fit: .contain)

  /// Upstream `defaultPatternSizing` (tiling pattern shaders).
  public static let defaultPattern = ShaderSizingParams(fit: .none)
}
