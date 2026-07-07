import simd

/// Port of upstream `simplex-noise.frag`.
public enum SimplexNoise {
  /// Descriptor.
  public static let descriptor = ShaderDescriptor(
    name: "simplex-noise",
    fragmentSource: source
  )

  /// Parameters used to render this shader.
  public struct Params {
    /// Colors.
    public var colors: [String]
    /// Steps per color.
    public var stepsPerColor: Float
    /// Softness.
    public var softness: Float
    /// Sizing.
    public var sizing: ShaderSizingParams
    /// Speed.
    public var speed: Double
    /// Frame.
    public var frame: Double

    /// Creates an instance.
    public init(
      colors: [String] = ["#4449CF", "#FFD1E0", "#F94446", "#FFD36B", "#FFFFFF"],
      stepsPerColor: Float = 2,
      softness: Float = 0,
      sizing: ShaderSizingParams = ShaderSizingParams(fit: .none, scale: 0.6),
      speed: Double = 0.5,
      frame: Double = 0
    ) {
      self.colors = colors
      self.stepsPerColor = stepsPerColor
      self.softness = softness
      self.sizing = sizing
      self.speed = speed
      self.frame = frame
    }

    /// Matches `SimplexNoiseUniforms` member order in the MSL source.
    public var uniforms: [UniformValue] {
      [
        .float4Array(colors.map(ShaderColor.parse), capacity: 10),
        .float(Float(colors.count)),
        .float(stepsPerColor),
        .float(softness),
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
      name: "Spots",
      params: Params(
        colors: ["#ff7b00", "#f9ffeb", "#320d82"],
        stepsPerColor: 1,
        softness: 0,
        sizing: ShaderSizingParams(fit: .none, scale: 1),
        speed: 0.6
      )
    ),
    Preset(
      name: "First contact",
      params: Params(
        colors: ["#e8cce6", "#120d22", "#442c44", "#e6baba", "#fff5f5"],
        stepsPerColor: 2,
        softness: 0,
        sizing: ShaderSizingParams(fit: .none, scale: 0.2),
        speed: 2
      )
    ),
    Preset(
      name: "Bubblegum",
      params: Params(
        colors: ["#ffffff", "#ff9e9e", "#5f57ff", "#00f7ff"],
        stepsPerColor: 1,
        softness: 1,
        sizing: ShaderSizingParams(fit: .none, scale: 1.6),
        speed: 2
      )
    ),
  ]

  static let source = """

  struct SimplexNoiseUniforms {
    float4 u_colors[10];
    float u_colorsCount;
    float u_stepsPerColor;
    float u_softness;
  };

  static float getNoise(float2 uv, float t) {
    float noise = .5 * snoise(uv - float2(0., .3 * t));
    noise += .5 * snoise(2. * uv + float2(0., .32 * t));

    return noise;
  }

  static float steppedSmooth(float m, float steps, float softness) {
    float stepT = floor(m * steps) / steps;
    float f = m * steps - floor(m * steps);
    float fw = steps * fwidth(m);
    float smoothed = smoothstep(.5 - softness, min(1., .5 + softness + fw), f);
    return stepT + smoothed / steps;
  }

  fragment float4 ps_fragment(PSVertexOut in [[stage_in]],
                              constant PSGlobalUniforms& global [[buffer(0)]],
                              constant SimplexNoiseUniforms& u [[buffer(1)]]) {
    float2 shape_uv = in.patternUV;
    shape_uv *= .1;

    float t = .2 * global.u_time;

    float shape = .5 + .5 * getNoise(shape_uv, t);

    bool u_extraSides = true;

    float mixer = shape * (u.u_colorsCount - 1.);
    if (u_extraSides == true) {
      mixer = (shape - .5 / u.u_colorsCount) * u.u_colorsCount;
    }

    float steps = max(1., u.u_stepsPerColor);

    float4 gradient = u.u_colors[0];
    gradient.rgb *= gradient.a;
    for (int i = 1; i < 10; i++) {
      if (i >= int(u.u_colorsCount)) break;

      float localM = clamp(mixer - float(i - 1), 0., 1.);
      localM = steppedSmooth(localM, steps, .5 * u.u_softness);

      float4 c = u.u_colors[i];
      c.rgb *= c.a;
      gradient = mix(gradient, c, localM);
    }

    if (u_extraSides == true) {
      if ((mixer < 0.) || (mixer > (u.u_colorsCount - 1.))) {
        float localM = mixer + 1.;
        if (mixer > (u.u_colorsCount - 1.)) {
          localM = mixer - (u.u_colorsCount - 1.);
        }
        localM = steppedSmooth(localM, steps, .5 * u.u_softness);
        float4 cFst = u.u_colors[0];
        cFst.rgb *= cFst.a;
        float4 cLast = u.u_colors[int(u.u_colorsCount - 1.)];
        cLast.rgb *= cLast.a;
        gradient = mix(cLast, cFst, localM);
      }
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
