import simd

/// Port of upstream `static-radial-gradient.frag` (static shader, no time uniform).
public enum StaticRadialGradient {
  /// Descriptor.
  public static let descriptor = ShaderDescriptor(
    name: "static-radial-gradient",
    fragmentSource: source,
    isAnimated: false
  )

  /// Parameters used to render this shader.
  public struct Params {
    /// Color back.
    public var colorBack: String
    /// Colors.
    public var colors: [String]
    /// Radius.
    public var radius: Float
    /// Focal distance.
    public var focalDistance: Float
    /// Focal angle.
    public var focalAngle: Float
    /// Falloff.
    public var falloff: Float
    /// Mixing.
    public var mixing: Float
    /// Distortion.
    public var distortion: Float
    /// Distortion shift.
    public var distortionShift: Float
    /// Distortion freq.
    public var distortionFreq: Float
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
      colorBack: String = "#000000",
      colors: [String] = ["#00bbff", "#00ffe1", "#ffffff"],
      radius: Float = 0.8,
      focalDistance: Float = 0.99,
      focalAngle: Float = 0,
      falloff: Float = 0.24,
      mixing: Float = 0.5,
      distortion: Float = 0,
      distortionShift: Float = 0,
      distortionFreq: Float = 12,
      grainMixer: Float = 0,
      grainOverlay: Float = 0,
      sizing: ShaderSizingParams = .defaultObject,
      speed: Double = 0,
      frame: Double = 0
    ) {
      self.colorBack = colorBack
      self.colors = colors
      self.radius = radius
      self.focalDistance = focalDistance
      self.focalAngle = focalAngle
      self.falloff = falloff
      self.mixing = mixing
      self.distortion = distortion
      self.distortionShift = distortionShift
      self.distortionFreq = distortionFreq
      self.grainMixer = grainMixer
      self.grainOverlay = grainOverlay
      self.sizing = sizing
      self.speed = speed
      self.frame = frame
    }

    /// Matches `StaticRadialGradientUniforms` member order in the MSL source.
    public var uniforms: [UniformValue] {
      [
        .float4(ShaderColor.parse(colorBack)),
        .float4Array(colors.map(ShaderColor.parse), capacity: 10),
        .float(Float(colors.count)),
        .float(radius),
        .float(focalDistance),
        .float(focalAngle),
        .float(falloff),
        .float(mixing),
        .float(distortion),
        .float(distortionShift),
        .float(distortionFreq),
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
      name: "Lo-Fi",
      params: Params(
        colorBack: "#2e1f27",
        colors: ["#d72638", "#3f88c5", "#f49d37"],
        radius: 1,
        focalDistance: 0,
        falloff: 0.9,
        mixing: 0.7,
        grainMixer: 1,
        grainOverlay: 0.5
      )
    ),
    Preset(
      name: "Cross Section",
      params: Params(
        colorBack: "#3d348b",
        colors: ["#7678ed", "#f7b801", "#f18701", "#37a066"],
        radius: 1,
        focalDistance: 0,
        falloff: 0,
        mixing: 0,
        distortion: 1
      )
    ),
    Preset(
      name: "Radial",
      params: Params(
        colorBack: "#264653",
        colors: ["#9c2b2b", "#f4a261", "#ffffff"],
        radius: 1,
        focalDistance: 0,
        falloff: 0,
        mixing: 1
      )
    ),
  ]

  static let source = """

  struct StaticRadialGradientUniforms {
    float4 u_colorBack;
    float4 u_colors[10];
    float u_colorsCount;
    float u_radius;
    float u_focalDistance;
    float u_focalAngle;
    float u_falloff;
    float u_mixing;
    float u_distortion;
    float u_distortionShift;
    float u_distortionFreq;
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

  fragment float4 ps_fragment(PSVertexOut in [[stage_in]],
                              constant PSGlobalUniforms& global [[buffer(0)]],
                              constant StaticRadialGradientUniforms& u [[buffer(1)]]) {
    float2 uv = 2. * in.objectUV;
    float2 grainUV = uv * 1000.;

    float2 center = float2(0.);
    // GLSL radians()
    float angleRad = -((u.u_focalAngle + 90.) * PI / 180.);
    float2 focalPoint = float2(cos(angleRad), sin(angleRad)) * u.u_focalDistance;
    float radius = u.u_radius;

    float2 c_to_uv = uv - center;
    float2 f_to_uv = uv - focalPoint;
    float2 f_to_c = center - focalPoint;
    float r = length(c_to_uv);

    float fragAngle = atan2(c_to_uv.y, c_to_uv.x);
    float angleDiff = fract((fragAngle - angleRad + PI) / TWO_PI) * TWO_PI - PI;

    float halfAngle = acos(clamp(radius / max(u.u_focalDistance, 1e-4), 0.0, 1.0));
    float e0 = 0.6 * PI, e1 = halfAngle;
    float lo = min(e0, e1), hi = max(e0, e1);
    float s  = smoothstep(lo, hi, abs(angleDiff));
    float isInSector = (e1 >= e0) ? (1.0 - s) : s;

    float a = dot(f_to_uv, f_to_uv);
    float b = -2.0 * dot(f_to_uv, f_to_c);
    float c = dot(f_to_c, f_to_c) - radius * radius;

    float discriminant = b * b - 4.0 * a * c;
    float t = 1.0;

    if (discriminant >= 0.0) {
      float sqrtD = sqrt(discriminant);
      float div = max(1e-4, 2.0 * a);
      float t0 = (-b - sqrtD) / div;
      float t1 = (-b + sqrtD) / div;
      t = max(t0, t1);
      if (t < 0.0) t = 0.0;
    }

    float dist = length(f_to_uv);
    float normalized = dist / max(1e-4, length(f_to_uv * t));
    float shape = clamp(normalized, 0.0, 1.0);

    float falloffMapped = mix(.2 + .8 * max(0., u.u_falloff + 1.), mix(1., 15., u.u_falloff * u.u_falloff), step(.0, u.u_falloff));

    float falloffExp = mix(falloffMapped, 1., shape);
    shape = pow(shape, falloffExp);
    shape = 1. - clamp(shape, 0., 1.);

    float outerMask = .002;
    float outer = 1.0 - smoothstep(radius - outerMask, radius + outerMask, r);
    outer = mix(outer, 1., isInSector);

    shape = mix(0., shape, outer);
    shape *= 1. - smoothstep(radius - .01, radius, r);

    float angle = atan2(f_to_uv.y, f_to_uv.x);
    shape -= pow(u.u_distortion, 2.) * shape * pow(abs(sin(PI * clamp(length(f_to_uv) - 0.2 + u.u_distortionShift, 0.0, 1.0))), 4.0) * (sin(u.u_distortionFreq * angle) + cos(floor(0.65 * u.u_distortionFreq) * angle));

    float grain = noise(grainUV, float2(0.));
    float mixerGrain = .4 * u.u_grainMixer * (grain - .5);

    float mixer = shape * u.u_colorsCount + mixerGrain;
    float4 gradient = u.u_colors[0];
    gradient.rgb *= gradient.a;

    float outerShape = 0.;
    for (int i = 1; i < 11; i++) {
      if (i > int(u.u_colorsCount)) break;
      float mLinear = clamp(mixer - float(i - 1), 0.0, 1.0);

      float aa = fwidth(mLinear);
      float width = min(u.u_mixing, 0.5);
      float t = clamp((mLinear - (0.5 - width - aa)) / (2. * width + 2. * aa), 0., 1.);
      float p = mix(2., 1., clamp((u.u_mixing - 0.5) * 2., 0., 1.));
      float m = t < 0.5
        ? 0.5 * pow(2. * t, p)
        : 1. - 0.5 * pow(2. * (1. - t), p);

      float quadBlend = clamp((u.u_mixing - 0.5) * 2., 0., 1.);
      m = mix(m, m * m, 0.5 * quadBlend);

      if (i == 1) {
        outerShape = m;
      }

      float4 c = u.u_colors[i - 1];
      c.rgb *= c.a;
      gradient = mix(gradient, c, m);
    }

    float3 color = gradient.rgb * outerShape;
    float opacity = gradient.a * outerShape;

    float3 bgColor = u.u_colorBack.rgb * u.u_colorBack.a;
    color = color + bgColor * (1.0 - opacity);
    opacity = opacity + u.u_colorBack.a * (1.0 - opacity);

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
