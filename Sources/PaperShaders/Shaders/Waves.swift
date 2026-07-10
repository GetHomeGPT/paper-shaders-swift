import simd

/// Port of upstream `waves.frag` (static shader, no time uniform).
public enum Waves {
  /// Descriptor.
  public static let descriptor = ShaderDescriptor(
    name: "waves",
    fragmentSource: source,
    isAnimated: false
  )

  /// Parameters used to render this shader.
  public struct Params {
    /// Color front.
    public var colorFront: String
    /// Color back.
    public var colorBack: String
    /// Shape.
    public var shape: Float
    /// Frequency.
    public var frequency: Float
    /// Amplitude.
    public var amplitude: Float
    /// Spacing.
    public var spacing: Float
    /// Proportion.
    public var proportion: Float
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
      colorFront: String = "#ffbb00",
      colorBack: String = "#000000",
      shape: Float = 0,
      frequency: Float = 0.5,
      amplitude: Float = 0.5,
      spacing: Float = 1.2,
      proportion: Float = 0.1,
      softness: Float = 0,
      sizing: ShaderSizingParams = ShaderSizingParams(fit: .none, scale: 0.6),
      speed: Double = 0,
      frame: Double = 0
    ) {
      self.colorFront = colorFront
      self.colorBack = colorBack
      self.shape = shape
      self.frequency = frequency
      self.amplitude = amplitude
      self.spacing = spacing
      self.proportion = proportion
      self.softness = softness
      self.sizing = sizing
      self.speed = speed
      self.frame = frame
    }

    /// Matches `WavesUniforms` member order in the MSL source.
    public var uniforms: [UniformValue] {
      [
        .float4(ShaderColor.parse(colorFront)),
        .float4(ShaderColor.parse(colorBack)),
        .float(shape),
        .float(frequency),
        .float(amplitude),
        .float(spacing),
        .float(proportion),
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
      name: "Groovy",
      params: Params(
        colorFront: "#fcfcee",
        colorBack: "#ff896b",
        shape: 3,
        frequency: 0.2,
        amplitude: 0.25,
        spacing: 1.17,
        proportion: 0.57,
        sizing: ShaderSizingParams(fit: .none, scale: 5, rotation: 90)
      )
    ),
    Preset(
      name: "Tangled up",
      params: Params(
        colorFront: "#133a41",
        colorBack: "#c2d8b6",
        shape: 2.07,
        frequency: 0.44,
        amplitude: 0.57,
        spacing: 1.05,
        proportion: 0.75,
        sizing: ShaderSizingParams(fit: .none, scale: 0.5)
      )
    ),
    Preset(
      name: "Ride the wave",
      params: Params(
        colorFront: "#fdffe6",
        colorBack: "#1f1f1f",
        shape: 2.25,
        frequency: 0.2,
        amplitude: 1,
        spacing: 1.25,
        proportion: 1,
        sizing: ShaderSizingParams(fit: .none, scale: 1.7)
      )
    ),
  ]

  static let source = """

  struct WavesUniforms {
    float4 u_colorFront;
    float4 u_colorBack;
    float u_shape;
    float u_frequency;
    float u_amplitude;
    float u_spacing;
    float u_proportion;
    float u_softness;
  };

  fragment float4 ps_fragment(PSVertexOut in [[stage_in]],
                              constant PSGlobalUniforms& global [[buffer(0)]],
                              constant WavesUniforms& u [[buffer(1)]]) {
    float2 shape_uv = in.patternUV;
    shape_uv *= 4.;

    float wave = .5 * cos(shape_uv.x * u.u_frequency * TWO_PI);
    float zigzag = 2. * abs(fract(shape_uv.x * u.u_frequency) - .5);
    float irregular = sin(shape_uv.x * .25 * u.u_frequency * TWO_PI) * cos(shape_uv.x * u.u_frequency * TWO_PI);
    float irregular2 = .75 * (sin(shape_uv.x * u.u_frequency * TWO_PI) + .5 * cos(shape_uv.x * .5 * u.u_frequency * TWO_PI));

    float offset = mix(zigzag, wave, smoothstep(0., 1., u.u_shape));
    offset = mix(offset, irregular, smoothstep(1., 2., u.u_shape));
    offset = mix(offset, irregular2, smoothstep(2., 3., u.u_shape));
    offset *= 2. * u.u_amplitude;

    float spacing = (.001 + u.u_spacing);
    float shape = .5 + .5 * sin((shape_uv.y + offset) * PI / spacing);

    float aa = .0001 + fwidth(shape);
    float dc = 1. - clamp(u.u_proportion, 0., 1.);
    float e0 = dc - u.u_softness - aa;
    float e1 = dc + u.u_softness + aa;
    float res = smoothstep(min(e0, e1), max(e0, e1), shape);

    float3 fgColor = u.u_colorFront.rgb * u.u_colorFront.a;
    float fgOpacity = u.u_colorFront.a;
    float3 bgColor = u.u_colorBack.rgb * u.u_colorBack.a;
    float bgOpacity = u.u_colorBack.a;

    float3 color = fgColor * res;
    float opacity = fgOpacity * res;

    color += bgColor * (1. - opacity);
    opacity += bgOpacity * (1. - opacity);

    return float4(color, opacity);
  }

  """
}
