import simd

/// Port of upstream `dot-grid.frag` (static shader, no time uniform).
public enum DotGrid {
  /// Descriptor.
  public static let descriptor = ShaderDescriptor(
    name: "dot-grid",
    fragmentSource: source
  )

  /// Options for shape.
  public enum Shape: String, Sendable {
    case circle
    case diamond
    case square
    case triangle

    /// Value passed to the `u_shape` uniform (upstream `DotGridShapes`).
    public var uniformValue: Float {
      switch self {
      case .circle: return 0
      case .diamond: return 1
      case .square: return 2
      case .triangle: return 3
      }
    }
  }

  /// Parameters used to render this shader.
  public struct Params {
    /// Color back.
    public var colorBack: String
    /// Color fill.
    public var colorFill: String
    /// Color stroke.
    public var colorStroke: String
    /// Size.
    public var size: Float
    /// Gap x.
    public var gapX: Float
    /// Gap y.
    public var gapY: Float
    /// Stroke width.
    public var strokeWidth: Float
    /// Size range.
    public var sizeRange: Float
    /// Opacity range.
    public var opacityRange: Float
    /// Shape.
    public var shape: Shape
    /// Sizing.
    public var sizing: ShaderSizingParams
    /// Speed.
    public var speed: Double
    /// Frame.
    public var frame: Double

    /// Creates an instance.
    public init(
      colorBack: String = "#000000",
      colorFill: String = "#ffffff",
      colorStroke: String = "#ffaa00",
      size: Float = 2,
      gapX: Float = 32,
      gapY: Float = 32,
      strokeWidth: Float = 0,
      sizeRange: Float = 0,
      opacityRange: Float = 0,
      shape: Shape = .circle,
      sizing: ShaderSizingParams = .defaultPattern,
      speed: Double = 0,
      frame: Double = 0
    ) {
      self.colorBack = colorBack
      self.colorFill = colorFill
      self.colorStroke = colorStroke
      self.size = size
      self.gapX = gapX
      self.gapY = gapY
      self.strokeWidth = strokeWidth
      self.sizeRange = sizeRange
      self.opacityRange = opacityRange
      self.shape = shape
      self.sizing = sizing
      self.speed = speed
      self.frame = frame
    }

    /// Matches `DotGridUniforms` member order in the MSL source.
    public var uniforms: [UniformValue] {
      [
        .float4(ShaderColor.parse(colorBack)),
        .float4(ShaderColor.parse(colorFill)),
        .float4(ShaderColor.parse(colorStroke)),
        .float(size),
        .float(gapX),
        .float(gapY),
        .float(strokeWidth),
        .float(sizeRange),
        .float(opacityRange),
        .float(shape.uniformValue),
      ]
    }
  }

  /// Named upstream preset for this shader.
  public struct Preset {
    /// Name.
    public let name: String
    /// Params.
    public let params: Params
  }

  /// Upstream presets (workbench manifest.json).
  public static let presets: [Preset] = [
    Preset(name: "Default", params: Params()),
    Preset(
      name: "Triangles",
      params: Params(
        colorBack: "#ffffff",
        colorFill: "#ffffff",
        colorStroke: "#808080",
        size: 5,
        strokeWidth: 1,
        shape: .triangle
      )
    ),
    Preset(
      name: "Tree line",
      params: Params(
        colorBack: "#f4fce7",
        colorFill: "#052e19",
        colorStroke: "#000000",
        size: 8,
        gapX: 20,
        gapY: 90,
        sizeRange: 1,
        opacityRange: 0.6,
        shape: .circle
      )
    ),
    Preset(
      name: "Wallpaper",
      params: Params(
        colorBack: "#204030",
        colorFill: "#000000",
        colorStroke: "#bd955b",
        size: 9,
        strokeWidth: 1,
        shape: .diamond
      )
    ),
  ]

  static let source = """

  struct DotGridUniforms {
    float4 u_colorBack;
    float4 u_colorFill;
    float4 u_colorStroke;
    float u_dotSize;
    float u_gapX;
    float u_gapY;
    float u_strokeWidth;
    float u_sizeRange;
    float u_opacityRange;
    float u_shape;
  };

  static float polygon(float2 p, float N, float rot) {
    float a = atan2(p.x, p.y) + rot;
    float r = TWO_PI / N;

    return cos(floor(.5 + a / r) * r - a) * length(p);
  }

  fragment float4 ps_fragment(PSVertexOut in [[stage_in]],
                              constant PSGlobalUniforms& global [[buffer(0)]],
                              constant DotGridUniforms& u [[buffer(1)]]) {
    // x100 is a default multiplier between vertex and fragment shaders
    // used upstream to avoid UV precision issues
    float2 shape_uv = 100. * in.patternUV;

    float2 gap = max(abs(float2(u.u_gapX, u.u_gapY)), float2(1e-6));
    float2 grid = fract(shape_uv / gap) + 1e-4;
    float2 grid_idx = floor(shape_uv / gap);
    float sizeRandomizer = .5 + .8 * snoise(2. * float2(grid_idx.x * 100., grid_idx.y));
    float opacity_randomizer = .5 + .7 * snoise(2. * float2(grid_idx.y, grid_idx.x));

    float2 center = float2(0.5) - 1e-3;
    float2 p = (grid - center) * float2(u.u_gapX, u.u_gapY);

    float baseSize = u.u_dotSize * (1. - sizeRandomizer * u.u_sizeRange);
    float strokeWidth = u.u_strokeWidth * (1. - sizeRandomizer * u.u_sizeRange);

    float dist;
    if (u.u_shape < 0.5) {
      // Circle
      dist = length(p);
    } else if (u.u_shape < 1.5) {
      // Diamond
      strokeWidth *= 1.5;
      dist = polygon(1.5 * p, 4., .25 * PI);
    } else if (u.u_shape < 2.5) {
      // Square
      dist = polygon(1.03 * p, 4., 1e-3);
    } else {
      // Triangle
      strokeWidth *= 1.5;
      p = p * 2. - 1.;
      p *= .9;
      p.y = 1. - p.y;
      p.y -= .75 * baseSize;
      dist = polygon(p, 3., 1e-3);
    }

    float edgeWidth = fwidth(dist);
    float shapeOuter = 1. - smoothstep(baseSize - edgeWidth, baseSize + edgeWidth, dist - strokeWidth);
    float shapeInner = 1. - smoothstep(baseSize - edgeWidth, baseSize + edgeWidth, dist);
    float stroke = shapeOuter - shapeInner;

    float dotOpacity = max(0., 1. - opacity_randomizer * u.u_opacityRange);
    stroke *= dotOpacity;
    shapeInner *= dotOpacity;

    stroke *= u.u_colorStroke.a;
    shapeInner *= u.u_colorFill.a;

    float3 color = float3(0.);
    color += stroke * u.u_colorStroke.rgb;
    color += shapeInner * u.u_colorFill.rgb;
    color += (1. - shapeInner - stroke) * u.u_colorBack.rgb * u.u_colorBack.a;

    float opacity = 0.;
    opacity += stroke;
    opacity += shapeInner;
    opacity += (1. - opacity) * u.u_colorBack.a;

    return float4(color, opacity);
  }

  """
}
