import simd

/// Port of upstream `voronoi.frag`.
public enum Voronoi {
  /// Descriptor.
  public static let descriptor = ShaderDescriptor(
    name: "voronoi",
    fragmentSource: source,
    usesNoiseTexture: true
  )

  /// Parameters used to render this shader.
  public struct Params {
    /// Colors.
    public var colors: [String]
    /// Steps per color.
    public var stepsPerColor: Float
    /// Color glow.
    public var colorGlow: String
    /// Color gap.
    public var colorGap: String
    /// Distortion.
    public var distortion: Float
    /// Gap.
    public var gap: Float
    /// Glow.
    public var glow: Float
    /// Sizing.
    public var sizing: ShaderSizingParams
    /// Speed.
    public var speed: Double
    /// Frame.
    public var frame: Double

    /// Creates an instance.
    public init(
      colors: [String] = ["#ff8247", "#ffe53d"],
      stepsPerColor: Float = 3,
      colorGlow: String = "#ffffff",
      colorGap: String = "#2e0000",
      distortion: Float = 0.4,
      gap: Float = 0.04,
      glow: Float = 0,
      sizing: ShaderSizingParams = ShaderSizingParams(fit: .none, scale: 0.5),
      speed: Double = 0.5,
      frame: Double = 0
    ) {
      self.colors = colors
      self.stepsPerColor = stepsPerColor
      self.colorGlow = colorGlow
      self.colorGap = colorGap
      self.distortion = distortion
      self.gap = gap
      self.glow = glow
      self.sizing = sizing
      self.speed = speed
      self.frame = frame
    }

    /// Matches `VoronoiUniforms` member order in the MSL source.
    /// Upstream passes the sizing `scale` prop as the `u_scale` uniform too.
    public var uniforms: [UniformValue] {
      [
        .float(sizing.scale),
        .float4Array(colors.map(ShaderColor.parse), capacity: 5),
        .float(Float(max(colors.count, 1))),
        .float(stepsPerColor),
        .float4(ShaderColor.parse(colorGlow)),
        .float4(ShaderColor.parse(colorGap)),
        .float(distortion),
        .float(gap),
        .float(glow),
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
      name: "Lights",
      params: Params(
        colors: ["#fffffffc", "#bbff00", "#00ffff"],
        stepsPerColor: 2,
        colorGlow: "#ff00d0",
        colorGap: "#ff00d0",
        distortion: 0.38,
        gap: 0,
        glow: 1,
        sizing: ShaderSizingParams(fit: .none, scale: 3.3)
      )
    ),
    Preset(
      name: "Cells",
      params: Params(
        colors: ["#ffffff"],
        stepsPerColor: 1,
        colorGlow: "#ffffff",
        colorGap: "#000000",
        distortion: 0.5,
        gap: 0.03,
        glow: 0.8,
        sizing: ShaderSizingParams(fit: .none, scale: 0.5)
      )
    ),
    Preset(
      name: "Bubbles",
      params: Params(
        colors: ["#83c9fb"],
        stepsPerColor: 1,
        colorGlow: "#ffffff",
        colorGap: "#ffffff",
        distortion: 0.4,
        gap: 0,
        glow: 1,
        sizing: ShaderSizingParams(fit: .none, scale: 0.75)
      )
    ),
  ]

  static let source = """

  struct VoronoiUniforms {
    float u_scale;
    float4 u_colors[5];
    float u_colorsCount;
    float u_stepsPerColor;
    float4 u_colorGlow;
    float4 u_colorGap;
    float u_distortion;
    float u_gap;
    float u_glow;
  };

  static float2 vRandomGB(float2 p, texture2d<float> noiseTex, sampler noiseSampler) {
    float2 uv = floor(p) / 100. + .5;
    return noiseTex.sample(noiseSampler, fract(uv)).gb;
  }

  static float4 voronoi(float2 x, float t, constant VoronoiUniforms& u,
                        texture2d<float> noiseTex, sampler noiseSampler) {
    float2 ip = floor(x);
    float2 fp = fract(x);

    float2 mg = float2(0.);
    float2 mr = float2(0.);
    float md = 8.;
    float rand = 0.;

    for (int j = -1; j <= 1; j++) {
      for (int i = -1; i <= 1; i++) {
        float2 g = float2(float(i), float(j));
        float2 o = vRandomGB(ip + g, noiseTex, noiseSampler);
        float raw_hash = o.x;
        o = .5 + u.u_distortion * sin(t + TWO_PI * o);
        float2 r = g + o - fp;
        float d = dot(r, r);

        if (d < md) {
          md = d;
          mr = r;
          mg = g;
          rand = raw_hash;
        }
      }
    }

    md = 8.;
    for (int j = -2; j <= 2; j++) {
      for (int i = -2; i <= 2; i++) {
        float2 g = mg + float2(float(i), float(j));
        float2 o = vRandomGB(ip + g, noiseTex, noiseSampler);
        o = .5 + u.u_distortion * sin(t + TWO_PI * o);
        float2 r = g + o - fp;
        if (dot(mr - r, mr - r) > .00001) {
          md = min(md, dot(.5 * (mr + r), normalize(r - mr)));
        }
      }
    }

    return float4(md, mr, rand);
  }

  fragment float4 ps_fragment(PSVertexOut in [[stage_in]],
                              constant PSGlobalUniforms& global [[buffer(0)]],
                              constant VoronoiUniforms& u [[buffer(1)]],
                              texture2d<float> noiseTex [[texture(0)]],
                              sampler noiseSampler [[sampler(0)]]) {
    float2 shape_uv = in.patternUV;
    shape_uv *= 1.25;

    float t = global.u_time;

    float4 voronoiRes = voronoi(shape_uv, t, u, noiseTex, noiseSampler);

    float shape = clamp(voronoiRes.w, 0., 1.);
    float mixer = shape * (u.u_colorsCount - 1.);
    mixer = (shape - .5 / u.u_colorsCount) * u.u_colorsCount;
    float steps = max(1., u.u_stepsPerColor);

    float4 gradient = u.u_colors[0];
    gradient.rgb *= gradient.a;
    for (int i = 1; i < 5; i++) {
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

    float3 cellColor = gradient.rgb;
    float cellOpacity = gradient.a;

    float glows = length(voronoiRes.yz * u.u_glow);
    glows = pow(glows, 1.5);

    float3 color = mix(cellColor, u.u_colorGlow.rgb * u.u_colorGlow.a, u.u_colorGlow.a * glows);
    float opacity = cellOpacity + u.u_colorGlow.a * glows;

    float edge = voronoiRes.x;
    float smoothEdge = .02 / (2. * u.u_scale) * (1. + .5 * u.u_gap);
    edge = smoothstep(u.u_gap - smoothEdge, u.u_gap + smoothEdge, edge);

    color = mix(u.u_colorGap.rgb * u.u_colorGap.a, color, edge);
    opacity = mix(u.u_colorGap.a, opacity, edge);

    return float4(color, opacity);
  }

  """
}
