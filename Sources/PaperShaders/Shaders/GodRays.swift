import simd

/// Port of upstream `god-rays.frag`.
public enum GodRays {
  /// Descriptor.
  public static let descriptor = ShaderDescriptor(
    name: "god-rays",
    fragmentSource: source,
    usesNoiseTexture: true
  )

  /// Parameters used to render this shader.
  public struct Params {
    /// Colors.
    public var colors: [String]
    /// Color back.
    public var colorBack: String
    /// Color bloom.
    public var colorBloom: String
    /// Density.
    public var density: Float
    /// Spotty.
    public var spotty: Float
    /// Mid size.
    public var midSize: Float
    /// Mid intensity.
    public var midIntensity: Float
    /// Intensity.
    public var intensity: Float
    /// Bloom.
    public var bloom: Float
    /// Sizing.
    public var sizing: ShaderSizingParams
    /// Speed.
    public var speed: Double
    /// Frame.
    public var frame: Double

    /// Creates an instance.
    public init(
      colors: [String] = ["#a600ff6e", "#6200fff0", "#ffffff", "#33fff5"],
      colorBack: String = "#000000",
      colorBloom: String = "#0000ff",
      density: Float = 0.3,
      spotty: Float = 0.3,
      midSize: Float = 0.2,
      midIntensity: Float = 0.4,
      intensity: Float = 0.8,
      bloom: Float = 0.4,
      sizing: ShaderSizingParams = ShaderSizingParams(fit: .contain, offsetY: -0.55),
      speed: Double = 0.75,
      frame: Double = 0
    ) {
      self.colors = colors
      self.colorBack = colorBack
      self.colorBloom = colorBloom
      self.density = density
      self.spotty = spotty
      self.midSize = midSize
      self.midIntensity = midIntensity
      self.intensity = intensity
      self.bloom = bloom
      self.sizing = sizing
      self.speed = speed
      self.frame = frame
    }

    /// Matches `GodRaysUniforms` member order in the MSL source.
    public var uniforms: [UniformValue] {
      [
        .float4(ShaderColor.parse(colorBack)),
        .float4(ShaderColor.parse(colorBloom)),
        .float4Array(colors.map(ShaderColor.parse), capacity: 5),
        .float(Float(max(colors.count, 1))),
        .float(density),
        .float(spotty),
        .float(midSize),
        .float(midIntensity),
        .float(intensity),
        .float(bloom),
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
      name: "Warp",
      params: Params(
        colors: ["#ff47d4", "#ff8c00", "#ffffff"],
        colorBack: "#000000",
        colorBloom: "#222288",
        density: 0.45,
        spotty: 0.15,
        midSize: 0.33,
        midIntensity: 0.4,
        intensity: 0.79,
        bloom: 0.4,
        sizing: ShaderSizingParams(fit: .contain),
        speed: 2
      )
    ),
    Preset(
      name: "Linear",
      params: Params(
        colors: ["#ffffff1f", "#ffffff3d", "#ffffff29"],
        colorBack: "#000000",
        colorBloom: "#eeeeee",
        density: 0.41,
        spotty: 0.25,
        midSize: 0.1,
        midIntensity: 0.75,
        intensity: 0.79,
        bloom: 1,
        sizing: ShaderSizingParams(fit: .contain, offsetX: 0.2, offsetY: -0.8),
        speed: 0.5
      )
    ),
    Preset(
      name: "Ether",
      params: Params(
        colors: ["#148effa6", "#c4dffebe", "#232a47"],
        colorBack: "#090f1d",
        colorBloom: "#ffffff",
        density: 0.03,
        spotty: 0.77,
        midSize: 0.1,
        midIntensity: 0.6,
        intensity: 0.6,
        bloom: 0.6,
        sizing: ShaderSizingParams(fit: .contain, offsetX: -0.6),
        speed: 1
      )
    ),
  ]

  static let source = """

  struct GodRaysUniforms {
    float4 u_colorBack;
    float4 u_colorBloom;
    float4 u_colors[5];
    float u_colorsCount;
    float u_density;
    float u_spotty;
    float u_midSize;
    float u_midIntensity;
    float u_intensity;
    float u_bloom;
  };

  static float grRandomR(float2 p, texture2d<float> noiseTex, sampler noiseSampler) {
    float2 uv = floor(p) / 100. + .5;
    return noiseTex.sample(noiseSampler, fract(uv)).r;
  }

  static float grValueNoise(float2 st, texture2d<float> noiseTex, sampler noiseSampler) {
    float2 i = floor(st);
    float2 f = fract(st);
    float a = grRandomR(i, noiseTex, noiseSampler);
    float b = grRandomR(i + float2(1.0, 0.0), noiseTex, noiseSampler);
    float c = grRandomR(i + float2(0.0, 1.0), noiseTex, noiseSampler);
    float d = grRandomR(i + float2(1.0, 1.0), noiseTex, noiseSampler);
    float2 u = f * f * (3.0 - 2.0 * f);
    float x1 = mix(a, b, u.x);
    float x2 = mix(c, d, u.x);
    return mix(x1, x2, u.y);
  }

  static float raysShape(float2 uv, float r, float freq, float intensity, float radius,
                         texture2d<float> noiseTex, sampler noiseSampler) {
    float a = atan2(uv.y, uv.x);
    float2 left = float2(a * freq, r);
    float2 right = float2(fract(a / TWO_PI) * TWO_PI * freq, r);
    float n_left = pow(grValueNoise(left, noiseTex, noiseSampler), intensity);
    float n_right = pow(grValueNoise(right, noiseTex, noiseSampler), intensity);
    float shape = mix(n_right, n_left, smoothstep(-.15, .15, uv.x));
    return shape;
  }

  fragment float4 ps_fragment(PSVertexOut in [[stage_in]],
                              constant PSGlobalUniforms& global [[buffer(0)]],
                              constant GodRaysUniforms& u [[buffer(1)]],
                              texture2d<float> noiseTex [[texture(0)]],
                              sampler noiseSampler [[sampler(0)]]) {
    float2 shape_uv = in.objectUV;

    float t = .2 * global.u_time;

    float radius = length(shape_uv);
    float spots = 6.5 * abs(u.u_spotty);

    float intensity = 4. - 3. * clamp(u.u_intensity, 0., 1.);

    float midSize = 10. * abs(u.u_midSize);
    float ms_lo = 0.02 * midSize;
    float ms_hi = max(midSize, 1e-6);
    float middleShape = pow(u.u_midIntensity, 0.3) * (1. - smoothstep(ms_lo, ms_hi, 3.0 * radius));
    middleShape = pow(middleShape, 5.0);

    float3 accumColor = float3(0.0);
    float accumAlpha = 0.0;

    for (int i = 0; i < 5; i++) {
      if (i >= int(u.u_colorsCount)) break;

      float2 rotatedUV = rotate(shape_uv, float(i) + 1.0);

      float r1 = radius * (1.0 + 0.4 * float(i)) - 3.0 * t;
      float r2 = 0.5 * radius * (1.0 + spots) - 2.0 * t;
      float density = 6. * u.u_density + step(.5, u.u_density) * pow(4.5 * (u.u_density - .5), 4.);
      float f = mix(1.0, 3.0 + 0.5 * float(i), hash11(float(i) * 15.)) * density;

      float ray = raysShape(rotatedUV, r1, 5.0 * f, intensity, radius, noiseTex, noiseSampler);
      ray *= raysShape(rotatedUV, r2, 4.0 * f, intensity, radius, noiseTex, noiseSampler);
      ray += (1. + 4. * ray) * middleShape;
      ray = clamp(ray, 0.0, 1.0);

      float srcAlpha = u.u_colors[i].a * ray;
      float3 srcColor = u.u_colors[i].rgb * srcAlpha;

      float3 alphaBlendColor = accumColor + (1.0 - accumAlpha) * srcColor;
      float alphaBlendAlpha = accumAlpha + (1.0 - accumAlpha) * srcAlpha;

      float3 addBlendColor = accumColor + srcColor;
      float addBlendAlpha = accumAlpha + srcAlpha;

      accumColor = mix(alphaBlendColor, addBlendColor, u.u_bloom);
      accumAlpha = mix(alphaBlendAlpha, addBlendAlpha, u.u_bloom);
    }

    float overlayAlpha = u.u_colorBloom.a;
    float3 overlayColor = u.u_colorBloom.rgb * overlayAlpha;

    float3 colorWithOverlay = accumColor + accumAlpha * overlayColor;
    accumColor = mix(accumColor, colorWithOverlay, u.u_bloom);

    float3 bgColor = u.u_colorBack.rgb * u.u_colorBack.a;

    float3 color = accumColor + (1. - accumAlpha) * bgColor;
    float opacity = accumAlpha + (1. - accumAlpha) * u.u_colorBack.a;
    color = clamp(color, 0., 1.);
    opacity = clamp(opacity, 0., 1.);

    // gl_FragCoord has a bottom-left origin, Metal's position is top-left
    float2 fragCoordGL = float2(in.position.x, global.u_resolution.y - in.position.y);
    color += 1. / 256. * (fract(sin(dot(.014 * fragCoordGL, float2(12.9898, 78.233))) * 43758.5453123) - .5);

    return float4(color, opacity);
  }

  """
}
