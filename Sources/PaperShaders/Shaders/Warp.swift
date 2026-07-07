import simd

/// Port of upstream `warp.frag`.
public enum Warp {
  /// Descriptor.
  public static let descriptor = ShaderDescriptor(
    name: "warp",
    fragmentSource: source,
    usesNoiseTexture: true
  )

  /// Options for shape.
  public enum Shape: String, Sendable {
    case checks
    case stripes
    case edge

    /// Value passed to the `u_shape` uniform (upstream `WarpShapes`).
    var uniformValue: Float {
      switch self {
      case .checks: return 0
      case .stripes: return 1
      case .edge: return 2
      }
    }
  }

  /// Parameters used to render this shader.
  public struct Params {
    /// Colors.
    public var colors: [String]
    /// Proportion.
    public var proportion: Float
    /// Softness.
    public var softness: Float
    /// Shape.
    public var shape: Shape
    /// Shape scale.
    public var shapeScale: Float
    /// Distortion.
    public var distortion: Float
    /// Swirl.
    public var swirl: Float
    /// Swirl iterations.
    public var swirlIterations: Float
    /// Sizing.
    public var sizing: ShaderSizingParams
    /// Speed.
    public var speed: Double
    /// Frame.
    public var frame: Double

    /// Creates an instance.
    public init(
      colors: [String] = ["#121212", "#9470ff", "#121212", "#8838ff"],
      proportion: Float = 0.45,
      softness: Float = 1,
      shape: Shape = .checks,
      shapeScale: Float = 0.1,
      distortion: Float = 0.25,
      swirl: Float = 0.8,
      swirlIterations: Float = 10,
      sizing: ShaderSizingParams = ShaderSizingParams(fit: .none),
      speed: Double = 1,
      frame: Double = 0
    ) {
      self.colors = colors
      self.proportion = proportion
      self.softness = softness
      self.shape = shape
      self.shapeScale = shapeScale
      self.distortion = distortion
      self.swirl = swirl
      self.swirlIterations = swirlIterations
      self.sizing = sizing
      self.speed = speed
      self.frame = frame
    }

    /// Matches `WarpUniforms` member order in the MSL source.
    /// Upstream also declares `u_scale`, but the fragment body never
    /// reads it, so the port drops it.
    public var uniforms: [UniformValue] {
      [
        .float4Array(colors.map(ShaderColor.parse), capacity: 10),
        .float(Float(max(colors.count, 1))),
        .float(proportion),
        .float(softness),
        .float(shape.uniformValue),
        .float(shapeScale),
        .float(distortion),
        .float(swirl),
        .float(swirlIterations),
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
      name: "Cauldron Pot",
      params: Params(
        colors: ["#a7e58b", "#324472", "#0a180d"],
        proportion: 0.64,
        softness: 1.5,
        shape: .edge,
        shapeScale: 0.6,
        distortion: 0.2,
        swirl: 0.86,
        swirlIterations: 7,
        sizing: ShaderSizingParams(fit: .none, scale: 0.9, rotation: 160),
        speed: 10
      )
    ),
    Preset(
      name: "Live Ink",
      params: Params(
        colors: ["#111314", "#9faeab", "#f3fee7", "#f3fee7"],
        proportion: 0.05,
        softness: 0,
        shape: .checks,
        shapeScale: 0.28,
        distortion: 0.25,
        swirl: 0.8,
        swirlIterations: 10,
        sizing: ShaderSizingParams(fit: .none, scale: 1.2, rotation: 44, offsetY: -0.3),
        speed: 2.5
      )
    ),
    Preset(
      name: "Kelp",
      params: Params(
        colors: ["#dbff8f", "#404f3e", "#091316"],
        proportion: 0.67,
        softness: 0,
        shape: .stripes,
        shapeScale: 1,
        distortion: 0,
        swirl: 0.2,
        swirlIterations: 3,
        sizing: ShaderSizingParams(fit: .none, scale: 0.8, rotation: 50),
        speed: 20
      )
    ),
    Preset(
      name: "Nectar",
      params: Params(
        colors: ["#151310", "#d3a86b", "#f0edea"],
        proportion: 0.24,
        softness: 1,
        shape: .edge,
        shapeScale: 0.75,
        distortion: 0.21,
        swirl: 0.57,
        swirlIterations: 10,
        sizing: ShaderSizingParams(fit: .none, scale: 2, offsetY: 0.6),
        speed: 4.2
      )
    ),
    Preset(
      name: "Passion",
      params: Params(
        colors: ["#3b1515", "#954751", "#ffc085"],
        proportion: 0.5,
        softness: 1,
        shape: .checks,
        shapeScale: 0.25,
        distortion: 0.09,
        swirl: 0.9,
        swirlIterations: 6,
        sizing: ShaderSizingParams(fit: .none, scale: 2.5, rotation: 1.35),
        speed: 3
      )
    ),
  ]

  static let source = """

  struct WarpUniforms {
    float4 u_colors[10];
    float u_colorsCount;
    float u_proportion;
    float u_softness;
    float u_shape;
    float u_shapeScale;
    float u_distortion;
    float u_swirl;
    float u_swirlIterations;
  };

  static float wRandomG(float2 p, texture2d<float> noiseTex, sampler noiseSampler) {
    float2 uv = floor(p) / 100. + .5;
    return noiseTex.sample(noiseSampler, fract(uv)).g;
  }

  static float wValueNoise(float2 st, texture2d<float> noiseTex, sampler noiseSampler) {
    float2 i = floor(st);
    float2 f = fract(st);
    float a = wRandomG(i, noiseTex, noiseSampler);
    float b = wRandomG(i + float2(1.0, 0.0), noiseTex, noiseSampler);
    float c = wRandomG(i + float2(0.0, 1.0), noiseTex, noiseSampler);
    float d = wRandomG(i + float2(1.0, 1.0), noiseTex, noiseSampler);
    float2 u = f * f * (3.0 - 2.0 * f);
    float x1 = mix(a, b, u.x);
    float x2 = mix(c, d, u.x);
    return mix(x1, x2, u.y);
  }

  fragment float4 ps_fragment(PSVertexOut in [[stage_in]],
                              constant PSGlobalUniforms& global [[buffer(0)]],
                              constant WarpUniforms& u [[buffer(1)]],
                              texture2d<float> noiseTex [[texture(0)]],
                              sampler noiseSampler [[sampler(0)]]) {
    float2 uv = in.patternUV;
    uv *= .5;

    const float firstFrameOffset = 118.;
    float t = 0.0625 * (global.u_time + firstFrameOffset);

    float n1 = wValueNoise(uv * 1. + t, noiseTex, noiseSampler);
    float n2 = wValueNoise(uv * 2. - t, noiseTex, noiseSampler);
    float angle = n1 * TWO_PI;
    uv.x += 4. * u.u_distortion * n2 * cos(angle);
    uv.y += 4. * u.u_distortion * n2 * sin(angle);

    float swirl = u.u_swirl;
    for (int i = 1; i <= 20; i++) {
      if (i >= int(u.u_swirlIterations)) break;
      float iFloat = float(i);
      uv.x += swirl / iFloat * cos(t + iFloat * 1.5 * uv.y);
      uv.y += swirl / iFloat * cos(t + iFloat * 1. * uv.x);
    }

    float proportion = clamp(u.u_proportion, 0., 1.);

    float shape = 0.;
    if (u.u_shape < .5) {
      float2 checksShape_uv = uv * (.5 + 3.5 * u.u_shapeScale);
      shape = .5 + .5 * sin(checksShape_uv.x) * cos(checksShape_uv.y);
      shape += .48 * sign(proportion - .5) * pow(abs(proportion - .5), .5);
    } else if (u.u_shape < 1.5) {
      float2 stripesShape_uv = uv * (2. * u.u_shapeScale);
      float f = fract(stripesShape_uv.y);
      shape = smoothstep(.0, .55, f) * (1.0 - smoothstep(.45, 1., f));
      shape += .48 * sign(proportion - .5) * pow(abs(proportion - .5), .5);
    } else {
      float shapeScaling = 5. * (1. - u.u_shapeScale);
      float e0 = 0.45 - shapeScaling;
      float e1 = 0.55 + shapeScaling;
      shape = smoothstep(min(e0, e1), max(e0, e1), 1.0 - uv.y + 0.3 * (proportion - 0.5));
    }

    float mixer = shape * (u.u_colorsCount - 1.);
    float4 gradient = u.u_colors[0];
    gradient.rgb *= gradient.a;
    float aa = fwidth(shape);
    for (int i = 1; i < 10; i++) {
      if (i >= int(u.u_colorsCount)) break;
      float m = clamp(mixer - float(i - 1), 0.0, 1.0);

      float localMixerStart = floor(m);
      float softness = .5 * u.u_softness + fwidth(m);
      float smoothed = smoothstep(max(0., .5 - softness - aa), min(1., .5 + softness + aa), m - localMixerStart);
      float stepped = localMixerStart + smoothed;

      m = mix(stepped, m, u.u_softness);

      float4 c = u.u_colors[i];
      c.rgb *= c.a;
      gradient = mix(gradient, c, m);
    }

    float3 color = gradient.rgb;
    float opacity = gradient.a;

    // gl_FragCoord has a bottom-left origin, Metal's position is top-left
    float2 fragCoordGL = float2(in.position.x, global.u_resolution.y - in.position.y);
    color += 1. / 256. * (fract(sin(dot(.014 * fragCoordGL, float2(12.9898, 78.233))) * 43758.5453123) - .5);

    return float4(color, opacity);
  }

  """
}
