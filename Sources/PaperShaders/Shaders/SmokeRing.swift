import simd

/// Port of upstream `smoke-ring.frag`.
public enum SmokeRing {
  /// Descriptor.
  public static let descriptor = ShaderDescriptor(
    name: "smoke-ring",
    fragmentSource: source,
    usesNoiseTexture: true
  )

  /// Parameters used to render this shader.
  public struct Params {
    /// Colors.
    public var colors: [String]
    /// Color back.
    public var colorBack: String
    /// Noise scale.
    public var noiseScale: Float
    /// Noise iterations.
    public var noiseIterations: Float
    /// Radius.
    public var radius: Float
    /// Thickness.
    public var thickness: Float
    /// Inner shape.
    public var innerShape: Float
    /// Sizing.
    public var sizing: ShaderSizingParams
    /// Speed.
    public var speed: Double
    /// Frame.
    public var frame: Double

    /// Creates an instance.
    public init(
      colors: [String] = ["#ffffff"],
      colorBack: String = "#000000",
      noiseScale: Float = 3,
      noiseIterations: Float = 8,
      radius: Float = 0.25,
      thickness: Float = 0.65,
      innerShape: Float = 0.7,
      sizing: ShaderSizingParams = ShaderSizingParams(fit: .contain, scale: 0.8),
      speed: Double = 0.5,
      frame: Double = 0
    ) {
      self.colors = colors
      self.colorBack = colorBack
      self.noiseScale = noiseScale
      self.noiseIterations = noiseIterations
      self.radius = radius
      self.thickness = thickness
      self.innerShape = innerShape
      self.sizing = sizing
      self.speed = speed
      self.frame = frame
    }

    /// Matches `SmokeRingUniforms` member order in the MSL source.
    public var uniforms: [UniformValue] {
      [
        .float4(ShaderColor.parse(colorBack)),
        .float4Array(colors.map(ShaderColor.parse), capacity: 10),
        .float(Float(max(colors.count, 1))),
        .float(thickness),
        .float(radius),
        .float(innerShape),
        .float(noiseScale),
        .float(noiseIterations),
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
      name: "Line",
      params: Params(
        colors: ["#4540a4", "#1fe8ff"],
        noiseScale: 1.1,
        noiseIterations: 2,
        radius: 0.38,
        thickness: 0.01,
        innerShape: 0.88,
        sizing: ShaderSizingParams(fit: .contain),
        speed: 4
      )
    ),
    Preset(
      name: "Solar",
      params: Params(
        colors: ["#ffffff", "#ffca0a", "#fc6203", "#fc620366"],
        noiseScale: 2,
        noiseIterations: 3,
        radius: 0.4,
        thickness: 0.8,
        innerShape: 4,
        sizing: ShaderSizingParams(fit: .contain, scale: 2, offsetY: 1),
        speed: 1
      )
    ),
    Preset(
      name: "Cloud",
      params: Params(
        colorBack: "#81ADEC",
        noiseScale: 3,
        noiseIterations: 10,
        radius: 0.5,
        thickness: 0.65,
        innerShape: 0.85,
        sizing: ShaderSizingParams(fit: .contain, scale: 2.5),
        speed: 0.5
      )
    ),
  ]

  static let source = """

  struct SmokeRingUniforms {
    float4 u_colorBack;
    float4 u_colors[10];
    float u_colorsCount;
    float u_thickness;
    float u_radius;
    float u_innerShape;
    float u_noiseScale;
    float u_noiseIterations;
  };

  static float srRandomR(float2 p, texture2d<float> noiseTex, sampler noiseSampler) {
    float2 uv = floor(p) / 100. + .5;
    return noiseTex.sample(noiseSampler, fract(uv)).r;
  }

  static float srValueNoise(float2 st, texture2d<float> noiseTex, sampler noiseSampler) {
    float2 i = floor(st);
    float2 f = fract(st);
    float a = srRandomR(i, noiseTex, noiseSampler);
    float b = srRandomR(i + float2(1.0, 0.0), noiseTex, noiseSampler);
    float c = srRandomR(i + float2(0.0, 1.0), noiseTex, noiseSampler);
    float d = srRandomR(i + float2(1.0, 1.0), noiseTex, noiseSampler);
    float2 u = f * f * (3.0 - 2.0 * f);
    float x1 = mix(a, b, u.x);
    float x2 = mix(c, d, u.x);
    return mix(x1, x2, u.y);
  }

  static float2 srFbm(float2 n0, float2 n1, constant SmokeRingUniforms& u,
                      texture2d<float> noiseTex, sampler noiseSampler) {
    float2 total = float2(0.0);
    float amplitude = .4;
    for (int i = 0; i < 8; i++) {
      if (i >= int(u.u_noiseIterations)) break;
      total.x += srValueNoise(n0, noiseTex, noiseSampler) * amplitude;
      total.y += srValueNoise(n1, noiseTex, noiseSampler) * amplitude;
      n0 *= 1.99;
      n1 *= 1.99;
      amplitude *= 0.65;
    }
    return total;
  }

  static float getNoise(float2 uv, float2 pUv, float t, constant SmokeRingUniforms& u,
                        texture2d<float> noiseTex, sampler noiseSampler) {
    float2 pUvLeft = pUv + .03 * t;
    float period = max(abs(u.u_noiseScale * TWO_PI), 1e-6);
    float2 pUvRight = float2(fract(pUv.x / period) * period, pUv.y) + .03 * t;
    float2 noise = srFbm(pUvLeft, pUvRight, u, noiseTex, noiseSampler);
    return mix(noise.y, noise.x, smoothstep(-.25, .25, uv.x));
  }

  static float getRingShape(float2 uv, constant SmokeRingUniforms& u) {
    float radius = u.u_radius;
    float thickness = u.u_thickness;

    float distance = length(uv);
    float ringValue = 1. - smoothstep(radius, radius + thickness, distance);
    ringValue *= smoothstep(radius - pow(u.u_innerShape, 3.) * thickness, radius, distance);

    return ringValue;
  }

  fragment float4 ps_fragment(PSVertexOut in [[stage_in]],
                              constant PSGlobalUniforms& global [[buffer(0)]],
                              constant SmokeRingUniforms& u [[buffer(1)]],
                              texture2d<float> noiseTex [[texture(0)]],
                              sampler noiseSampler [[sampler(0)]]) {
    float2 shape_uv = in.objectUV;

    float t = global.u_time;

    float cycleDuration = 3.;
    float period2 = 2.0 * cycleDuration;
    float localTime1 = fract((0.1 * t + cycleDuration) / period2) * period2;
    float localTime2 = fract((0.1 * t) / period2) * period2;
    float timeBlend = .5 + .5 * sin(.1 * t * PI / cycleDuration - .5 * PI);

    float atg = atan2(shape_uv.y, shape_uv.x) + .001;
    float l = length(shape_uv);
    float radialOffset = .5 * l - rsqrt(max(1e-4, l));
    float2 polar_uv1 = float2(atg, localTime1 - radialOffset) * u.u_noiseScale;
    float2 polar_uv2 = float2(atg, localTime2 - radialOffset) * u.u_noiseScale;

    float noise1 = getNoise(shape_uv, polar_uv1, t, u, noiseTex, noiseSampler);
    float noise2 = getNoise(shape_uv, polar_uv2, t, u, noiseTex, noiseSampler);

    float noise = mix(noise1, noise2, timeBlend);

    shape_uv *= (.8 + 1.2 * noise);

    float ringShape = getRingShape(shape_uv, u);

    float mixer = ringShape * ringShape * (u.u_colorsCount - 1.);
    int idxLast = int(u.u_colorsCount) - 1;
    float4 gradient = u.u_colors[idxLast];
    gradient.rgb *= gradient.a;
    for (int i = 10 - 2; i >= 0; i--) {
      float localT = clamp(mixer - float(idxLast - i - 1), 0., 1.);
      float4 c = u.u_colors[i];
      c.rgb *= c.a;
      gradient = mix(gradient, c, localT);
    }

    float3 color = gradient.rgb * ringShape;
    float opacity = gradient.a * ringShape;

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
