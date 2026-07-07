import simd

/// Port of upstream `swirl.frag`.
public enum Swirl {
  /// Descriptor.
  public static let descriptor = ShaderDescriptor(
    name: "swirl",
    fragmentSource: source
  )

  /// Parameters used to render this shader.
  public struct Params {
    /// Color back.
    public var colorBack: String
    /// Colors.
    public var colors: [String]
    /// Band count.
    public var bandCount: Float
    /// Twist.
    public var twist: Float
    /// Center.
    public var center: Float
    /// Proportion.
    public var proportion: Float
    /// Softness.
    public var softness: Float
    /// Noise.
    public var noise: Float
    /// Noise frequency.
    public var noiseFrequency: Float
    /// Sizing.
    public var sizing: ShaderSizingParams
    /// Speed.
    public var speed: Double
    /// Frame.
    public var frame: Double

    /// Creates an instance.
    public init(
      colorBack: String = "#330000",
      colors: [String] = ["#ffd1d1", "#ff8a8a", "#660000"],
      bandCount: Float = 4,
      twist: Float = 0.1,
      center: Float = 0.2,
      proportion: Float = 0.5,
      softness: Float = 0,
      noise: Float = 0.2,
      noiseFrequency: Float = 0.4,
      sizing: ShaderSizingParams = .defaultObject,
      speed: Double = 0.32,
      frame: Double = 0
    ) {
      self.colorBack = colorBack
      self.colors = colors
      self.bandCount = bandCount
      self.twist = twist
      self.center = center
      self.proportion = proportion
      self.softness = softness
      self.noise = noise
      self.noiseFrequency = noiseFrequency
      self.sizing = sizing
      self.speed = speed
      self.frame = frame
    }

    /// Matches `SwirlUniforms` member order in the MSL source.
    public var uniforms: [UniformValue] {
      [
        .float4(ShaderColor.parse(colorBack)),
        .float4Array(colors.map(ShaderColor.parse), capacity: 10),
        .float(Float(colors.count)),
        .float(bandCount),
        .float(twist),
        .float(center),
        .float(proportion),
        .float(softness),
        .float(noise),
        .float(noiseFrequency),
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
      name: "007",
      params: Params(
        colorBack: "#E9E7DA",
        colors: ["#000000"],
        bandCount: 5,
        twist: 0.3,
        center: 0,
        proportion: 0,
        noise: 0,
        noiseFrequency: 0.5,
        speed: 1
      )
    ),
    Preset(
      name: "Opening",
      params: Params(
        colorBack: "#ff8b61",
        colors: ["#fefff0", "#ffd8bd", "#ff8b61"],
        bandCount: 2,
        twist: 0.3,
        noise: 0,
        noiseFrequency: 0,
        sizing: ShaderSizingParams(fit: .contain, offsetX: -0.4, offsetY: 1),
        speed: 0.5
      )
    ),
    Preset(
      name: "Candy",
      params: Params(
        colorBack: "#ffcd66",
        colors: ["#6bbceb", "#d7b3ff", "#ff9fff"],
        bandCount: 2,
        twist: 0.15,
        softness: 1,
        noise: 0,
        noiseFrequency: 0.5,
        speed: 1
      )
    ),
  ]

  static let source = """

  struct SwirlUniforms {
    float4 u_colorBack;
    float4 u_colors[10];
    float u_colorsCount;
    float u_bandCount;
    float u_twist;
    float u_center;
    float u_proportion;
    float u_softness;
    float u_noise;
    float u_noiseFrequency;
  };

  fragment float4 ps_fragment(PSVertexOut in [[stage_in]],
                              constant PSGlobalUniforms& global [[buffer(0)]],
                              constant SwirlUniforms& u [[buffer(1)]]) {
    float2 shape_uv = in.objectUV;

    float l = length(shape_uv);
    l = max(1e-4, l);

    float t = global.u_time;

    float angle = ceil(u.u_bandCount) * atan2(shape_uv.y, shape_uv.x) + t;
    float angle_norm = angle / TWO_PI;

    float twist = 3. * clamp(u.u_twist, 0., 1.);
    float offset = pow(l, -twist) + angle_norm;

    float shape = fract(offset);
    shape = 1. - abs(2. * shape - 1.);
    shape += u.u_noise * snoise(15. * pow(u.u_noiseFrequency, 2.) * shape_uv);

    float mid = smoothstep(.2, .2 + .8 * u.u_center, pow(l, twist));
    shape = mix(0., shape, mid);

    float proportion = clamp(u.u_proportion, 0., 1.);
    float exponent = mix(.25, 1., proportion * 2.);
    exponent = mix(exponent, 10., max(0., proportion * 2. - 1.));
    shape = pow(shape, exponent);

    float mixer = shape * u.u_colorsCount;
    float4 gradient = u.u_colors[0];
    gradient.rgb *= gradient.a;

    float outerShape = 0.;
    for (int i = 1; i < 11; i++) {
      if (i > int(u.u_colorsCount)) break;

      float m = clamp(mixer - float(i - 1), 0., 1.);
      float aa = fwidth(m);
      m = smoothstep(.5 - .5 * u.u_softness - aa, .5 + .5 * u.u_softness + aa, m);

      if (i == 1) {
        outerShape = m;
      }

      float4 c = u.u_colors[i - 1];
      c.rgb *= c.a;
      gradient = mix(gradient, c, m);
    }

    float midAA = .1 * fwidth(pow(l, -twist));
    float outerMid = smoothstep(.2, .2 + midAA, pow(l, twist));
    outerShape = mix(0., outerShape, outerMid);

    float3 color = gradient.rgb * outerShape;
    float opacity = gradient.a * outerShape;

    float3 bgColor = u.u_colorBack.rgb * u.u_colorBack.a;
    color = color + bgColor * (1.0 - opacity);
    opacity = opacity + u.u_colorBack.a * (1.0 - opacity);

    // gl_FragCoord has a bottom-left origin, Metal's position is top-left
    float2 fragCoordGL = float2(in.position.x, global.u_resolution.y - in.position.y);
    color += 1. / 256. * (fract(sin(dot(.014 * fragCoordGL, float2(12.9898, 78.233))) * 43758.5453123) - .5);

    return float4(color, opacity);
  }

  """
}
