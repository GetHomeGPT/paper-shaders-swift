import simd

/// Port of upstream `dot-orbit.frag` (uses the shared 128×128 noise texture).
public enum DotOrbit {
  /// Descriptor.
  public static let descriptor = ShaderDescriptor(
    name: "dot-orbit",
    fragmentSource: source,
    usesNoiseTexture: true
  )

  /// Parameters used to render this shader.
  public struct Params {
    /// Color back.
    public var colorBack: String
    /// Colors.
    public var colors: [String]
    /// Steps per color.
    public var stepsPerColor: Float
    /// Size.
    public var size: Float
    /// Size range.
    public var sizeRange: Float
    /// Spreading.
    public var spreading: Float
    /// Sizing.
    public var sizing: ShaderSizingParams
    /// Speed.
    public var speed: Double
    /// Frame.
    public var frame: Double

    /// Creates an instance.
    public init(
      colorBack: String = "#000000",
      colors: [String] = ["#ffc96b", "#ff6200", "#ff2f00", "#421100", "#1a0000"],
      stepsPerColor: Float = 4,
      size: Float = 1,
      sizeRange: Float = 0,
      spreading: Float = 1,
      sizing: ShaderSizingParams = ShaderSizingParams(fit: .none, scale: 1),
      speed: Double = 1.5,
      frame: Double = 0
    ) {
      self.colorBack = colorBack
      self.colors = colors
      self.stepsPerColor = stepsPerColor
      self.size = size
      self.sizeRange = sizeRange
      self.spreading = spreading
      self.sizing = sizing
      self.speed = speed
      self.frame = frame
    }

    /// Matches `DotOrbitUniforms` member order in the MSL source.
    public var uniforms: [UniformValue] {
      [
        .float4(ShaderColor.parse(colorBack)),
        .float4Array(colors.map(ShaderColor.parse), capacity: 10),
        .float(Float(colors.count)),
        .float(stepsPerColor),
        .float(size),
        .float(sizeRange),
        .float(spreading),
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
      name: "Bubbles",
      params: Params(
        colorBack: "#989CA4",
        colors: ["#D0D2D5"],
        stepsPerColor: 2,
        size: 0.9,
        sizeRange: 0.7,
        spreading: 1,
        sizing: ShaderSizingParams(fit: .none, scale: 1.64),
        speed: 0.4
      )
    ),
    Preset(
      name: "Shine",
      params: Params(
        colorBack: "#000000",
        colors: ["#ffffff", "#006aff", "#fff675"],
        stepsPerColor: 4,
        size: 0.3,
        sizeRange: 0.2,
        spreading: 1,
        sizing: ShaderSizingParams(fit: .none, scale: 0.4),
        speed: 0.1
      )
    ),
    Preset(
      name: "Hallucinatory",
      params: Params(
        colorBack: "#ffe500",
        colors: ["#000000"],
        stepsPerColor: 2,
        size: 0.65,
        sizeRange: 0,
        spreading: 0.3,
        sizing: ShaderSizingParams(fit: .none, scale: 0.5),
        speed: 5
      )
    ),
  ]

  static let source = """

  struct DotOrbitUniforms {
    float4 u_colorBack;
    float4 u_colors[10];
    float u_colorsCount;
    float u_stepsPerColor;
    float u_size;
    float u_sizeRange;
    float u_spreading;
  };

  static float randomR(float2 p, texture2d<float> noiseTexture, sampler noiseSampler) {
    float2 uv = floor(p) / 100. + .5;
    return noiseTexture.sample(noiseSampler, fract(uv)).r;
  }

  static float2 randomGB(float2 p, texture2d<float> noiseTexture, sampler noiseSampler) {
    float2 uv = floor(p) / 100. + .5;
    return noiseTexture.sample(noiseSampler, fract(uv)).gb;
  }

  static float3 voronoiShape(float2 uv, float time, float spreadingParam,
                             texture2d<float> noiseTexture, sampler noiseSampler) {
    float2 i_uv = floor(uv);
    float2 f_uv = fract(uv);

    float spreading = .25 * clamp(spreadingParam, 0., 1.);

    float minDist = 1.;
    float2 randomizer = float2(0.);
    for (int y = -1; y <= 1; y++) {
      for (int x = -1; x <= 1; x++) {
        float2 tileOffset = float2(float(x), float(y));
        float2 rand = randomGB(i_uv + tileOffset, noiseTexture, noiseSampler);
        float2 cellCenter = float2(.5 + 1e-4);
        cellCenter += spreading * cos(time + TWO_PI * rand);
        cellCenter -= .5;
        cellCenter = rotate(cellCenter, randomR(float2(rand.x, rand.y), noiseTexture, noiseSampler) + .1 * time);
        cellCenter += .5;
        float dist = length(tileOffset + cellCenter - f_uv);
        if (dist < minDist) {
          minDist = dist;
          randomizer = rand;
        }
      }
    }

    return float3(minDist, randomizer);
  }

  fragment float4 ps_fragment(PSVertexOut in [[stage_in]],
                              constant PSGlobalUniforms& global [[buffer(0)]],
                              constant DotOrbitUniforms& u [[buffer(1)]],
                              texture2d<float> u_noiseTexture [[texture(0)]],
                              sampler noiseSampler [[sampler(0)]]) {
    float2 shape_uv = in.patternUV;
    shape_uv *= 1.5;

    const float firstFrameOffset = -10.;
    float t = global.u_time + firstFrameOffset;

    float3 voronoi = voronoiShape(shape_uv, t, u.u_spreading, u_noiseTexture, noiseSampler) + 1e-4;

    float radius = .25 * clamp(u.u_size, 0., 1.) - .5 * clamp(u.u_sizeRange, 0., 1.) * voronoi[2];
    float dist = voronoi[0];
    float edgeWidth = fwidth(dist);
    float dots = 1. - smoothstep(radius - edgeWidth, radius + edgeWidth, dist);

    float shape = voronoi[1];

    float mixer = shape * (u.u_colorsCount - 1.);
    mixer = (shape - .5 / u.u_colorsCount) * u.u_colorsCount;
    float steps = max(1., u.u_stepsPerColor);

    float4 gradient = u.u_colors[0];
    gradient.rgb *= gradient.a;
    for (int i = 1; i < 10; i++) {
      if (i >= int(u.u_colorsCount)) break;
      float localT = clamp(mixer - float(i - 1), 0.0, 1.0);
      localT = round(localT * steps) / steps;
      float4 c = u.u_colors[i];
      c.rgb *= c.a;
      gradient = mix(gradient, c, localT);
    }

    if ((mixer < 0.) || (mixer > (u.u_colorsCount - 1.))) {
      float localT = mixer + 1.;
      if (mixer > (u.u_colorsCount - 1.)) {
        localT = mixer - (u.u_colorsCount - 1.);
      }
      localT = round(localT * steps) / steps;
      float4 cFst = u.u_colors[0];
      cFst.rgb *= cFst.a;
      float4 cLast = u.u_colors[int(u.u_colorsCount - 1.)];
      cLast.rgb *= cLast.a;
      gradient = mix(cLast, cFst, localT);
    }

    float3 color = gradient.rgb * dots;
    float opacity = gradient.a * dots;

    float3 bgColor = u.u_colorBack.rgb * u.u_colorBack.a;
    color = color + bgColor * (1. - opacity);
    opacity = opacity + u.u_colorBack.a * (1. - opacity);

    return float4(color, opacity);
  }

  """
}
