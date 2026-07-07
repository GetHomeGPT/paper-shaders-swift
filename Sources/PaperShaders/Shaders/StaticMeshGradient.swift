import simd

/// Port of upstream `static-mesh-gradient.frag` (static shader, no time uniform).
public enum StaticMeshGradient {
  /// Descriptor.
  public static let descriptor = ShaderDescriptor(
    name: "static-mesh-gradient",
    fragmentSource: source
  )

  /// Parameters used to render this shader.
  public struct Params {
    /// Colors.
    public var colors: [String]
    /// Positions.
    public var positions: Float
    /// Wave x.
    public var waveX: Float
    /// Wave xshift.
    public var waveXShift: Float
    /// Wave y.
    public var waveY: Float
    /// Wave yshift.
    public var waveYShift: Float
    /// Mixing.
    public var mixing: Float
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
      colors: [String] = ["#ffad0a", "#6200ff", "#e2a3ff", "#ff99fd"],
      positions: Float = 2,
      waveX: Float = 1,
      waveXShift: Float = 0.6,
      waveY: Float = 1,
      waveYShift: Float = 0.21,
      mixing: Float = 0.93,
      grainMixer: Float = 0,
      grainOverlay: Float = 0,
      sizing: ShaderSizingParams = .defaultObject,
      speed: Double = 0,
      frame: Double = 0
    ) {
      self.colors = colors
      self.positions = positions
      self.waveX = waveX
      self.waveXShift = waveXShift
      self.waveY = waveY
      self.waveYShift = waveYShift
      self.mixing = mixing
      self.grainMixer = grainMixer
      self.grainOverlay = grainOverlay
      self.sizing = sizing
      self.speed = speed
      self.frame = frame
    }

    /// Matches `StaticMeshGradientUniforms` member order in the MSL source.
    public var uniforms: [UniformValue] {
      [
        .float4Array(colors.map(ShaderColor.parse), capacity: 10),
        .float(Float(colors.count)),
        .float(positions),
        .float(waveX),
        .float(waveXShift),
        .float(waveY),
        .float(waveYShift),
        .float(mixing),
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
    Preset(
      name: "Default",
      params: Params(sizing: ShaderSizingParams(fit: .contain, rotation: 270))
    ),
    Preset(
      name: "1960s",
      params: Params(
        colors: ["#000000", "#082400", "#b1aa91", "#8e8c15"],
        positions: 42,
        waveX: 0.45,
        waveXShift: 0,
        waveY: 1,
        waveYShift: 0,
        mixing: 0,
        grainMixer: 0.37,
        grainOverlay: 0.78
      )
    ),
    Preset(
      name: "Sunset",
      params: Params(
        colors: ["#264653", "#9c2b2b", "#f4a261", "#ffffff"],
        positions: 0,
        waveX: 0.6,
        waveXShift: 0.7,
        waveY: 0.7,
        waveYShift: 0.7,
        mixing: 0.5
      )
    ),
    Preset(
      name: "Sea",
      params: Params(
        colors: ["#013b65", "#03738c", "#a3d3ff", "#f2faef"],
        positions: 0,
        waveX: 0.53,
        waveXShift: 0,
        waveY: 0.95,
        waveYShift: 0.64,
        mixing: 0.5
      )
    ),
  ]

  static let source = """

  struct StaticMeshGradientUniforms {
    float4 u_colors[10];
    float u_colorsCount;
    float u_positions;
    float u_waveX;
    float u_waveXShift;
    float u_waveY;
    float u_waveYShift;
    float u_mixing;
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
    float b = .6 + glsl_mod(float(i), 3.) * .3;
    float c = .8 + glsl_mod(float(i + 1), 4.) * 0.25;

    float x = sin(t * b + a);
    float y = cos(t * c + a * 1.5);

    return .5 + .5 * float2(x, y);
  }

  fragment float4 ps_fragment(PSVertexOut in [[stage_in]],
                              constant PSGlobalUniforms& global [[buffer(0)]],
                              constant StaticMeshGradientUniforms& u [[buffer(1)]]) {
    float2 uv = in.objectUV;
    uv += .5;
    float2 grainUV = uv * 1000.;

    float grain = noise(grainUV, float2(0.));
    float mixerGrain = .4 * u.u_grainMixer * (grain - .5);

    float radius = smoothstep(0., 1., length(uv - .5));
    float center = 1. - radius;
    for (float i = 1.; i <= 2.; i++) {
      uv.x += u.u_waveX * center / i * cos(TWO_PI * u.u_waveXShift + i * 2. * smoothstep(.0, 1., uv.y));
      uv.y += u.u_waveY * center / i * cos(TWO_PI * u.u_waveYShift + i * 2. * smoothstep(.0, 1., uv.x));
    }

    float3 color = float3(0.);
    float opacity = 0.;
    float totalWeight = 0.;
    float positionSeed = 25. + .33 * u.u_positions;

    for (int i = 0; i < 10; i++) {
      if (i >= int(u.u_colorsCount)) break;

      float2 pos = getPosition(i, positionSeed) + mixerGrain;
      float dist = length(uv - pos);
      dist = length(uv - pos);

      float3 colorFraction = u.u_colors[i].rgb * u.u_colors[i].a;
      float opacityFraction = u.u_colors[i].a;

      float mixing = pow(u.u_mixing, .7);
      float power = mix(2., 1., mixing);
      dist = pow(dist, power);

      float w = 1. / (dist + 1e-3);
      float baseSharpness = mix(.0, 8., clamp(w, 0., 1.));
      float sharpness = mix(baseSharpness, 1., mixing);
      w = pow(w, sharpness);
      color += colorFraction * w;
      opacity += opacityFraction * w;
      totalWeight += w;
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
