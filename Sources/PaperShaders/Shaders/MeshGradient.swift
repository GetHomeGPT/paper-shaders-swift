import simd

/// Port of upstream `mesh-gradient.frag`.
public enum MeshGradient {
  /// Descriptor.
  public static let descriptor = ShaderDescriptor(
    name: "mesh-gradient",
    fragmentSource: source
  )

  /// Parameters used to render this shader.
  public struct Params {
    /// Colors.
    public var colors: [String]
    /// Distortion.
    public var distortion: Float
    /// Swirl.
    public var swirl: Float
    /// Grain mixer.
    public var grainMixer: Float
    /// Grain overlay.
    public var grainOverlay: Float
    /// Sizing.
    public var sizing: ShaderSizingParams
    /// Speed.
    public var speed: Double
    /// Frame.
    public var frame: Double

    /// Creates an instance.
    public init(
      colors: [String] = ["#e0eaff", "#241d9a", "#f75092", "#9f50d3"],
      distortion: Float = 0.8,
      swirl: Float = 0.1,
      grainMixer: Float = 0,
      grainOverlay: Float = 0,
      sizing: ShaderSizingParams = .defaultObject,
      speed: Double = 1,
      frame: Double = 0
    ) {
      self.colors = colors
      self.distortion = distortion
      self.swirl = swirl
      self.grainMixer = grainMixer
      self.grainOverlay = grainOverlay
      self.sizing = sizing
      self.speed = speed
      self.frame = frame
    }

    /// Matches `MeshGradientUniforms` member order in the MSL source.
    public var uniforms: [UniformValue] {
      [
        .float4Array(colors.map(ShaderColor.parse), capacity: 10),
        .float(Float(colors.count)),
        .float(distortion),
        .float(swirl),
        .float(grainMixer),
        .float(grainOverlay),
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
      name: "Ink",
      params: Params(
        colors: ["#ffffff", "#000000"],
        distortion: 1,
        swirl: 0.2,
        sizing: ShaderSizingParams(fit: .contain, rotation: 90),
        speed: 1
      )
    ),
    Preset(
      name: "Purple",
      params: Params(
        colors: ["#aaa7d7", "#3c2b8e"],
        distortion: 1,
        swirl: 1,
        speed: 0.6
      )
    ),
    Preset(
      name: "Beach",
      params: Params(
        colors: ["#bcecf6", "#00aaff", "#00f7ff", "#ffd447"],
        distortion: 0.8,
        swirl: 0.35,
        speed: 0.1
      )
    ),
  ]

  static let source = """

  struct MeshGradientUniforms {
    float4 u_colors[10];
    float u_colorsCount;
    float u_distortion;
    float u_swirl;
    float u_grainMixer;
    float u_grainOverlay;
  };

  static float valueNoise(float2 st) {
    float2 i = floor(st);
    float2 f = fract(st);
    float a = hash21(i);
    float b = hash21(i + float2(1.0, 0.0));
    float c = hash21(i + float2(0.0, 1.0));
    float d = hash21(i + float2(1.0, 1.0));
    float2 u = f * f * (3.0 - 2.0 * f);
    float x1 = mix(a, b, u.x);
    float x2 = mix(c, d, u.x);
    return mix(x1, x2, u.y);
  }

  static float noise(float2 n, float2 seedOffset) {
    return valueNoise(n + seedOffset);
  }

  static float2 getPosition(int i, float t) {
    float a = float(i) * .37;
    float b = .6 + fract(float(i) / 3.) * .9;
    float c = .8 + fract(float(i + 1) / 4.);

    float x = sin(t * b + a);
    float y = cos(t * c + a * 1.5);

    return .5 + .5 * float2(x, y);
  }

  fragment float4 ps_fragment(PSVertexOut in [[stage_in]],
                              constant PSGlobalUniforms& global [[buffer(0)]],
                              constant MeshGradientUniforms& u [[buffer(1)]]) {
    float2 uv = in.objectUV;
    uv += .5;
    float2 grainUV = uv * 1000.;

    float grain = noise(grainUV, float2(0.));
    float mixerGrain = .4 * u.u_grainMixer * (grain - .5);

    const float firstFrameOffset = 41.5;
    float t = .5 * (global.u_time + firstFrameOffset);

    float radius = smoothstep(0., 1., length(uv - .5));
    float center = 1. - radius;
    for (float i = 1.; i <= 2.; i++) {
      uv.x += u.u_distortion * center / i * sin(t + i * .4 * smoothstep(.0, 1., uv.y)) * cos(.2 * t + i * 2.4 * smoothstep(.0, 1., uv.y));
      uv.y += u.u_distortion * center / i * cos(t + i * 2. * smoothstep(.0, 1., uv.x));
    }

    float2 uvRotated = uv;
    uvRotated -= float2(.5);
    float angle = 3. * u.u_swirl * radius;
    uvRotated = rotate(uvRotated, -angle);
    uvRotated += float2(.5);

    float3 color = float3(0.);
    float opacity = 0.;
    float totalWeight = 0.;

    for (int i = 0; i < 10; i++) {
      if (i >= int(u.u_colorsCount)) break;

      float2 pos = getPosition(i, t) + mixerGrain;
      float3 colorFraction = u.u_colors[i].rgb * u.u_colors[i].a;
      float opacityFraction = u.u_colors[i].a;

      float dist = length(uvRotated - pos);

      dist = pow(dist, 3.5);
      float weight = 1. / (dist + 1e-3);
      color += colorFraction * weight;
      opacity += opacityFraction * weight;
      totalWeight += weight;
    }

    color /= max(1e-4, totalWeight);
    opacity /= max(1e-4, totalWeight);

    float grainOverlay = valueNoise(rotate(grainUV, 1.) + float2(3.));
    grainOverlay = mix(grainOverlay, valueNoise(rotate(grainUV, 2.) + float2(-1.)), .5);
    grainOverlay = pow(grainOverlay, 1.3);

    float grainOverlayV = grainOverlay * 2. - 1.;
    float3 grainOverlayColor = float3(step(0., grainOverlayV));
    float grainOverlayStrength = u.u_grainOverlay * abs(grainOverlayV);
    grainOverlayStrength = pow(grainOverlayStrength, .8);
    color = mix(color, grainOverlayColor, .35 * grainOverlayStrength);

    opacity += .5 * grainOverlayStrength;
    opacity = clamp(opacity, 0., 1.);

    return float4(color, opacity);
  }

  """
}
