import simd

/// Port of upstream `water.frag`.
public enum Water {
  /// Descriptor.
  public static let descriptor = ShaderDescriptor(
    name: "water",
    fragmentSource: source,
    usesImageTexture: true
  )

  /// Parameters used to render this shader.
  public struct Params {
    /// Color back.
    public var colorBack: String
    /// Color highlight.
    public var colorHighlight: String
    /// Highlights.
    public var highlights: Float
    /// Layering.
    public var layering: Float
    /// Edges.
    public var edges: Float
    /// Caustic.
    public var caustic: Float
    /// Waves.
    public var waves: Float
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
      colorBack: String = "#909090",
      colorHighlight: String = "#ffffff",
      highlights: Float = 0.07,
      layering: Float = 0.5,
      edges: Float = 0.8,
      caustic: Float = 0.1,
      waves: Float = 0.3,
      size: Float = 1,
      sizing: ShaderSizingParams = ShaderSizingParams(fit: .contain, scale: 0.8),
      speed: Double = 1,
      frame: Double = 0
    ) {
      self.colorBack = colorBack
      self.colorHighlight = colorHighlight
      self.highlights = highlights
      self.layering = layering
      self.edges = edges
      self.caustic = caustic
      self.waves = waves
      self.size = size
      self.sizing = sizing
      self.speed = speed
      self.frame = frame
    }

    /// Matches `WaterUniforms` member order in the MSL source.
    public var uniforms: [UniformValue] {
      [
        .float4(ShaderColor.parse(colorBack)),
        .float4(ShaderColor.parse(colorHighlight)),
        .float(highlights),
        .float(layering),
        .float(edges),
        .float(caustic),
        .float(waves),
        .float(size),
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
      name: "Slow-mo",
      params: Params(
        highlights: 0.4,
        layering: 0,
        edges: 0,
        caustic: 0.2,
        waves: 0,
        size: 0.7,
        sizing: ShaderSizingParams(fit: .cover),
        speed: 0.1
      )
    ),
    Preset(
      name: "Abstract",
      params: Params(
        highlights: 0,
        layering: 0,
        edges: 1,
        caustic: 0.4,
        waves: 1,
        size: 0.15,
        sizing: ShaderSizingParams(fit: .cover, scale: 3)
      )
    ),
    Preset(
      name: "Streaming",
      params: Params(
        highlights: 0,
        layering: 0,
        edges: 0,
        caustic: 0,
        waves: 0.5,
        size: 0.5,
        sizing: ShaderSizingParams(fit: .contain, scale: 0.4),
        speed: 2
      )
    ),
  ]

  static let source = """

  struct WaterUniforms {
    float4 u_colorBack;
    float4 u_colorHighlight;
    float u_highlights;
    float u_layering;
    float u_edges;
    float u_caustic;
    float u_waves;
    float u_size;
  };

  static float waterGetUvFrame(float2 uv) {
    float aax = 2. * fwidth(uv.x);
    float aay = 2. * fwidth(uv.y);

    float left = smoothstep(0., aax, uv.x);
    float right = 1.0 - smoothstep(1. - aax, 1., uv.x);
    float bottom = smoothstep(0., aay, uv.y);
    float top = 1.0 - smoothstep(1. - aay, 1., uv.y);

    return left * right * bottom * top;
  }

  static float2x2 waterRotate2D(float r) {
    return float2x2(float2(cos(r), sin(r)), float2(-sin(r), cos(r)));
  }

  static float waterGetCausticNoise(float2 uv, float t, float scale) {
    float2 n = float2(.1);
    float2 N = float2(.1);
    float2x2 m = waterRotate2D(.5);
    for (int j = 0; j < 6; j++) {
      uv = uv * m;
      n = n * m;
      float fj = float(j);
      float2 q = uv * scale + fj + n + (.5 + .5 * fj) * (glsl_mod(fj, 2.) - 1.) * t;
      n += sin(q);
      N += cos(q) / scale;
      scale *= 1.1;
    }
    return N.x + N.y + 1.;
  }

  fragment float4 ps_fragment(PSVertexOut in [[stage_in]],
                              constant PSGlobalUniforms& global [[buffer(0)]],
                              constant WaterUniforms& u [[buffer(1)]],
                              constant PSSizingUniforms& sizing [[buffer(2)]],
                              texture2d<float> imageTex [[texture(1)]],
                              sampler imageSampler [[sampler(1)]]) {
    float2 imageUV = in.imageUV;
    float2 patternUV = in.imageUV - .5;
    patternUV = patternUV * float2(sizing.u_imageAspectRatio, 1.);
    patternUV /= (.01 + .09 * u.u_size);

    float t = global.u_time;

    float wavesNoise = snoise((.3 + .1 * sin(t)) * .1 * patternUV + float2(0., .4 * t));

    float causticNoise = waterGetCausticNoise(patternUV + u.u_waves * float2(1., -1.) * wavesNoise, 2. * t, 1.5);

    causticNoise += u.u_layering * waterGetCausticNoise(patternUV + 2. * u.u_waves * float2(1., -1.) * wavesNoise, 1.5 * t, 2.);
    causticNoise = causticNoise * causticNoise;

    float edgesDistortion = smoothstep(0., .1, imageUV.x);
    edgesDistortion *= smoothstep(0., .1, imageUV.y);
    edgesDistortion *= (smoothstep(1., 1.1, imageUV.x) + (1.0 - smoothstep(.8, .95, imageUV.x)));
    edgesDistortion *= (1.0 - smoothstep(.9, 1., imageUV.y));
    edgesDistortion = mix(edgesDistortion, 1., u.u_edges);

    float causticNoiseDistortion = .02 * causticNoise * edgesDistortion;

    float wavesDistortion = .1 * u.u_waves * wavesNoise;

    imageUV += float2(wavesDistortion, -wavesDistortion);
    imageUV += u.u_caustic * causticNoiseDistortion;

    float frame = waterGetUvFrame(imageUV);

    float4 image = imageTex.sample(imageSampler, imageUV);
    float4 backColor = u.u_colorBack;
    backColor.rgb *= backColor.a;

    float3 color = mix(backColor.rgb, image.rgb, image.a * frame);
    float opacity = backColor.a + image.a * frame;

    causticNoise = max(-.2, causticNoise);

    float hightlight = .025 * u.u_highlights * causticNoise;
    hightlight *= u.u_colorHighlight.a;
    color = mix(color, u.u_colorHighlight.rgb, .05 * u.u_highlights * causticNoise);
    opacity += hightlight;

    color += hightlight * (.5 + .5 * wavesNoise);
    opacity += hightlight * (.5 + .5 * wavesNoise);

    opacity = clamp(opacity, 0., 1.);

    return float4(color, opacity);
  }

  """
}
