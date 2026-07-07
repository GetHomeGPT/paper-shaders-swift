import simd

/// Port of upstream `perlin-noise.frag`.
public enum PerlinNoise {
  /// Descriptor.
  public static let descriptor = ShaderDescriptor(
    name: "perlin-noise",
    fragmentSource: source
  )

  /// Parameters used to render this shader.
  public struct Params {
    /// Color front.
    public var colorFront: String
    /// Color back.
    public var colorBack: String
    /// Proportion.
    public var proportion: Float
    /// Softness.
    public var softness: Float
    /// Octave count.
    public var octaveCount: Float
    /// Persistence.
    public var persistence: Float
    /// Lacunarity.
    public var lacunarity: Float
    /// Sizing.
    public var sizing: ShaderSizingParams
    /// Speed.
    public var speed: Double
    /// Frame.
    public var frame: Double

    /// Creates an instance.
    public init(
      colorFront: String = "#fccff7",
      colorBack: String = "#632ad5",
      proportion: Float = 0.35,
      softness: Float = 0.1,
      octaveCount: Float = 1,
      persistence: Float = 1,
      lacunarity: Float = 1.5,
      sizing: ShaderSizingParams = .defaultPattern,
      speed: Double = 0.5,
      frame: Double = 0
    ) {
      self.colorFront = colorFront
      self.colorBack = colorBack
      self.proportion = proportion
      self.softness = softness
      self.octaveCount = octaveCount
      self.persistence = persistence
      self.lacunarity = lacunarity
      self.sizing = sizing
      self.speed = speed
      self.frame = frame
    }

    /// Matches `PerlinNoiseUniforms` member order in the MSL source.
    public var uniforms: [UniformValue] {
      [
        .float4(ShaderColor.parse(colorFront)),
        .float4(ShaderColor.parse(colorBack)),
        .float(proportion),
        .float(softness),
        .float(octaveCount),
        .float(persistence),
        .float(lacunarity),
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
      name: "Nintendo Water",
      params: Params(
        colorFront: "#d1eefc",
        colorBack: "#2d69d4",
        proportion: 0.42,
        softness: 0,
        octaveCount: 2,
        persistence: 0.55,
        lacunarity: 1.8,
        sizing: ShaderSizingParams(fit: .none, scale: 5),
        speed: 0.4
      )
    ),
    Preset(
      name: "Moss",
      params: Params(
        colorFront: "#262626",
        colorBack: "#05ff4a",
        proportion: 0.65,
        softness: 0.35,
        octaveCount: 6,
        persistence: 1,
        lacunarity: 2.55,
        sizing: ShaderSizingParams(fit: .none, scale: 6.666666666666667),
        speed: 0.02
      )
    ),
    Preset(
      name: "Worms",
      params: Params(
        colorFront: "#595959",
        colorBack: "#ffffff00",
        proportion: 0.5,
        softness: 0,
        octaveCount: 1,
        persistence: 1,
        lacunarity: 1.5,
        sizing: ShaderSizingParams(fit: .none, scale: 0.9),
        speed: 0
      )
    ),
  ]

  static let source = """

  struct PerlinNoiseUniforms {
    float4 u_colorFront;
    float4 u_colorBack;
    float u_proportion;
    float u_softness;
    float u_octaveCount;
    float u_persistence;
    float u_lacunarity;
  };

  static float hash31(float3 p) {
    p = fract(p * 0.3183099) + 0.1;
    p += dot(p, p.yzx + 19.19);
    return fract(p.x * (p.y + p.z));
  }

  static float3 gradientPredefined(float hash) {
    int idx = int(hash * 12.0) % 12;

    if (idx == 0) return float3(1, 1, 0);
    if (idx == 1) return float3(-1, 1, 0);
    if (idx == 2) return float3(1, -1, 0);
    if (idx == 3) return float3(-1, -1, 0);
    if (idx == 4) return float3(1, 0, 1);
    if (idx == 5) return float3(-1, 0, 1);
    if (idx == 6) return float3(1, 0, -1);
    if (idx == 7) return float3(-1, 0, -1);
    if (idx == 8) return float3(0, 1, 1);
    if (idx == 9) return float3(0, -1, 1);
    if (idx == 10) return float3(0, 1, -1);
    return float3(0, -1, -1); // idx == 11
  }

  static float interpolateSafe(float v000, float v001, float v010, float v011,
  float v100, float v101, float v110, float v111, float3 t) {
    t = clamp(t, 0.0, 1.0);

    float v00 = mix(v000, v100, t.x);
    float v01 = mix(v001, v101, t.x);
    float v10 = mix(v010, v110, t.x);
    float v11 = mix(v011, v111, t.x);

    float v0 = mix(v00, v10, t.y);
    float v1 = mix(v01, v11, t.y);

    return mix(v0, v1, t.z);
  }

  static float3 fade(float3 t) {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
  }

  static float perlinNoise(float3 position, float seed) {
    position += float3(seed * 127.1, seed * 311.7, seed * 74.7);

    float3 i = floor(position);
    float3 f = fract(position);
    float h000 = hash31(i);
    float h001 = hash31(i + float3(0, 0, 1));
    float h010 = hash31(i + float3(0, 1, 0));
    float h011 = hash31(i + float3(0, 1, 1));
    float h100 = hash31(i + float3(1, 0, 0));
    float h101 = hash31(i + float3(1, 0, 1));
    float h110 = hash31(i + float3(1, 1, 0));
    float h111 = hash31(i + float3(1, 1, 1));
    float3 g000 = gradientPredefined(h000);
    float3 g001 = gradientPredefined(h001);
    float3 g010 = gradientPredefined(h010);
    float3 g011 = gradientPredefined(h011);
    float3 g100 = gradientPredefined(h100);
    float3 g101 = gradientPredefined(h101);
    float3 g110 = gradientPredefined(h110);
    float3 g111 = gradientPredefined(h111);
    float v000 = dot(g000, f - float3(0, 0, 0));
    float v001 = dot(g001, f - float3(0, 0, 1));
    float v010 = dot(g010, f - float3(0, 1, 0));
    float v011 = dot(g011, f - float3(0, 1, 1));
    float v100 = dot(g100, f - float3(1, 0, 0));
    float v101 = dot(g101, f - float3(1, 0, 1));
    float v110 = dot(g110, f - float3(1, 1, 0));
    float v111 = dot(g111, f - float3(1, 1, 1));

    float3 u = fade(f);
    return interpolateSafe(v000, v001, v010, v011, v100, v101, v110, v111, u);
  }

  static float p_noise(float3 position, int octaveCount, float persistence, float lacunarity) {
    float value = 0.0;
    float amplitude = 1.0;
    float frequency = 10.0;
    float maxValue = 0.0;
    octaveCount = clamp(octaveCount, 1, 8);

    for (int i = 0; i < octaveCount; i++) {
      float seed = float(i) * 0.7319;
      value += perlinNoise(position * frequency, seed) * amplitude;
      maxValue += amplitude;
      amplitude *= persistence;
      frequency *= lacunarity;
    }
    return value;
  }

  static float get_max_amp(float persistence, float octaveCount) {
    persistence = clamp(persistence * 0.999, 0.0, 0.999);
    octaveCount = clamp(octaveCount, 1.0, 8.0);

    if (abs(persistence - 1.0) < 0.001) {
      return octaveCount;
    }

    return (1.0 - pow(persistence, octaveCount)) / max(1e-4, (1.0 - persistence));
  }

  fragment float4 ps_fragment(PSVertexOut in [[stage_in]],
                              constant PSGlobalUniforms& global [[buffer(0)]],
                              constant PerlinNoiseUniforms& u [[buffer(1)]]) {
    float2 uv = in.patternUV;
    uv *= .5;

    float t = .2 * global.u_time;

    float3 p = float3(uv, t);

    float octCount = floor(u.u_octaveCount);
    float noise = p_noise(p, int(octCount), u.u_persistence, u.u_lacunarity);

    float max_amp = get_max_amp(u.u_persistence, octCount);
    float noise_normalized = clamp((noise + max_amp) / max(1e-4, (2. * max_amp)) + (u.u_proportion - .5), 0.0, 1.0);
    float sharpness = clamp(u.u_softness, 0., 1.);
    float smooth_w = 0.5 * max(fwidth(noise_normalized), 0.001);
    float res = smoothstep(
    .5 - .5 * sharpness - smooth_w,
    .5 + .5 * sharpness + smooth_w,
    noise_normalized
    );

    float3 fgColor = u.u_colorFront.rgb * u.u_colorFront.a;
    float fgOpacity = u.u_colorFront.a;
    float3 bgColor = u.u_colorBack.rgb * u.u_colorBack.a;
    float bgOpacity = u.u_colorBack.a;

    float3 color = fgColor * res;
    float opacity = fgOpacity * res;

    color += bgColor * (1. - opacity);
    opacity += bgOpacity * (1. - opacity);

    // gl_FragCoord has a bottom-left origin, Metal's position is top-left
    float2 fragCoordGL = float2(in.position.x, global.u_resolution.y - in.position.y);
    color += 1. / 256. * (fract(sin(dot(.014 * fragCoordGL, float2(12.9898, 78.233))) * 43758.5453123) - .5);

    return float4(color, opacity);
  }

  """
}
