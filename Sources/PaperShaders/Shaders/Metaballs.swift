import simd

/// Port of upstream `metaballs.frag`.
public enum Metaballs {
  /// Descriptor.
  public static let descriptor = ShaderDescriptor(
    name: "metaballs",
    fragmentSource: source,
    usesNoiseTexture: true
  )

  /// Parameters used to render this shader.
  public struct Params {
    /// Colors.
    public var colors: [String]
    /// Color back.
    public var colorBack: String
    /// Count.
    public var count: Float
    /// Size.
    public var size: Float
    /// Sizing.
    public var sizing: ShaderSizingParams
    /// Speed.
    public var speed: Double
    /// Frame.
    public var frame: Double

    /// Creates an instance.
    public init(
      colors: [String] = ["#6e33cc", "#ff5500", "#ffc105", "#ffc800", "#f585ff"],
      colorBack: String = "#000000",
      count: Float = 10,
      size: Float = 0.83,
      sizing: ShaderSizingParams = ShaderSizingParams(fit: .contain),
      speed: Double = 1,
      frame: Double = 0
    ) {
      self.colors = colors
      self.colorBack = colorBack
      self.count = count
      self.size = size
      self.sizing = sizing
      self.speed = speed
      self.frame = frame
    }

    /// Matches `MetaballsUniforms` member order in the MSL source.
    /// Upstream also declares `u_sizeRange`, but neither the fragment body
    /// nor the React component ever use it, so the port drops it.
    public var uniforms: [UniformValue] {
      [
        .float4(ShaderColor.parse(colorBack)),
        .float4Array(colors.map(ShaderColor.parse), capacity: 8),
        // Clamped to 1: the shader indexes with `i % colorsCount`,
        // a zero count would be a modulo by zero.
        .float(Float(max(colors.count, 1))),
        .float(size),
        .float(count),
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
      name: "Ink Drops",
      params: Params(
        colors: ["#000000"],
        colorBack: "#ffffff00",
        count: 18,
        size: 0.1,
        speed: 2
      )
    ),
    Preset(
      name: "Solar",
      params: Params(
        colors: ["#ffc800", "#ff5500", "#ffc105"],
        colorBack: "#102f84",
        count: 7,
        size: 0.75
      )
    ),
    Preset(
      name: "Background",
      params: Params(
        colors: ["#ae00ff", "#00ff95", "#ffc105"],
        colorBack: "#2a273f",
        count: 13,
        size: 0.81,
        sizing: ShaderSizingParams(fit: .contain, scale: 4, offsetX: -0.3),
        speed: 0.5
      )
    ),
  ]

  static let source = """

  struct MetaballsUniforms {
    float4 u_colorBack;
    float4 u_colors[8];
    float u_colorsCount;
    float u_size;
    float u_count;
  };

  static float mbRandomR(float2 p, texture2d<float> noiseTex, sampler noiseSampler) {
    float2 uv = floor(p) / 100. + .5;
    return noiseTex.sample(noiseSampler, fract(uv)).r;
  }

  static float mbNoise(float x, texture2d<float> noiseTex, sampler noiseSampler) {
    float i = floor(x);
    float f = fract(x);
    float u = f * f * (3.0 - 2.0 * f);
    float2 p0 = float2(i, 0.0);
    float2 p1 = float2(i + 1.0, 0.0);
    return mix(mbRandomR(p0, noiseTex, noiseSampler), mbRandomR(p1, noiseTex, noiseSampler), u);
  }

  static float getBallShape(float2 uv, float2 c, float p) {
    float s = .5 * length(uv - c);
    s = 1. - clamp(s, 0., 1.);
    s = pow(s, p);
    return s;
  }

  fragment float4 ps_fragment(PSVertexOut in [[stage_in]],
                              constant PSGlobalUniforms& global [[buffer(0)]],
                              constant MetaballsUniforms& u [[buffer(1)]],
                              texture2d<float> noiseTex [[texture(0)]],
                              sampler noiseSampler [[sampler(0)]]) {
    float2 shape_uv = in.objectUV;

    shape_uv += .5;

    const float firstFrameOffset = 2503.4;
    float t = .2 * (global.u_time + firstFrameOffset);

    float3 totalColor = float3(0.);
    float totalShape = 0.;
    float totalOpacity = 0.;

    for (int i = 0; i < 20; i++) {
      if (i >= int(ceil(u.u_count))) break;

      float idxFract = float(i) / 20.0;
      float angle = TWO_PI * idxFract;

      float speed = 1. - .2 * idxFract;
      float noiseX = mbNoise(angle * 10. + float(i) + t * speed, noiseTex, noiseSampler);
      float noiseY = mbNoise(angle * 20. + float(i) - t * speed, noiseTex, noiseSampler);

      float2 pos = float2(.5) + 1e-4 + .9 * (float2(noiseX, noiseY) - .5);

      int safeIndex = i % int(u.u_colorsCount + 0.5);
      float4 ballColor = u.u_colors[safeIndex];
      ballColor.rgb *= ballColor.a;

      float sizeFrac = 1.;
      if (float(i) > floor(u.u_count - 1.)) {
        sizeFrac *= fract(u.u_count);
      }

      float shape = getBallShape(shape_uv, pos, 45. - 30. * u.u_size * sizeFrac);
      shape *= pow(u.u_size, .2);
      shape = smoothstep(0., 1., shape);

      totalColor += ballColor.rgb * shape;
      totalShape += shape;
      totalOpacity += ballColor.a * shape;
    }

    totalColor /= max(totalShape, 1e-4);
    totalOpacity /= max(totalShape, 1e-4);

    float edge_width = fwidth(totalShape);
    float finalShape = smoothstep(.4, .4 + edge_width, totalShape);

    float3 color = totalColor * finalShape;
    float opacity = totalOpacity * finalShape;

    float3 bgColor = u.u_colorBack.rgb * u.u_colorBack.a;
    color = color + bgColor * (1. - opacity);
    opacity = opacity + u.u_colorBack.a * (1. - opacity);

    // gl_FragCoord has a bottom-left origin, Metal's position is top-left
    float2 fragCoordGL = float2(in.position.x, global.u_resolution.y - in.position.y);
    color += 1. / 256. * (fract(sin(dot(.014 * fragCoordGL, float2(12.9898, 78.233))) * 43758.5453123) - .5);

    return float4(color, opacity);
  }

  """
}
