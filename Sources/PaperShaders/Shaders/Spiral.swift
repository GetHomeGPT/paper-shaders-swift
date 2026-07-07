import simd

/// Port of upstream `spiral.frag`.
public enum Spiral {
  /// Descriptor.
  public static let descriptor = ShaderDescriptor(
    name: "spiral",
    fragmentSource: source
  )

  /// Parameters used to render this shader.
  public struct Params {
    /// Color back.
    public var colorBack: String
    /// Color front.
    public var colorFront: String
    /// Density.
    public var density: Float
    /// Distortion.
    public var distortion: Float
    /// Stroke width.
    public var strokeWidth: Float
    /// Stroke cap.
    public var strokeCap: Float
    /// Stroke taper.
    public var strokeTaper: Float
    /// Noise.
    public var noise: Float
    /// Noise frequency.
    public var noiseFrequency: Float
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
      colorBack: String = "#001429",
      colorFront: String = "#79D1FF",
      density: Float = 1,
      distortion: Float = 0,
      strokeWidth: Float = 0.5,
      strokeCap: Float = 0,
      strokeTaper: Float = 0,
      noise: Float = 0,
      noiseFrequency: Float = 0,
      softness: Float = 0,
      sizing: ShaderSizingParams = .defaultPattern,
      speed: Double = 1,
      frame: Double = 0
    ) {
      self.colorBack = colorBack
      self.colorFront = colorFront
      self.density = density
      self.distortion = distortion
      self.strokeWidth = strokeWidth
      self.strokeCap = strokeCap
      self.strokeTaper = strokeTaper
      self.noise = noise
      self.noiseFrequency = noiseFrequency
      self.softness = softness
      self.sizing = sizing
      self.speed = speed
      self.frame = frame
    }

    /// Matches `SpiralUniforms` member order in the MSL source.
    public var uniforms: [UniformValue] {
      [
        .float4(ShaderColor.parse(colorBack)),
        .float4(ShaderColor.parse(colorFront)),
        .float(density),
        .float(distortion),
        .float(strokeWidth),
        .float(strokeCap),
        .float(strokeTaper),
        .float(noise),
        .float(noiseFrequency),
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
      name: "Jungle",
      params: Params(
        colorBack: "#a0ef2a",
        colorFront: "#288b18",
        density: 0.5,
        noise: 1,
        noiseFrequency: 0.25,
        sizing: ShaderSizingParams(fit: .none, scale: 1.3),
        speed: 0.75
      )
    ),
    Preset(
      name: "Droplet",
      params: Params(
        colorBack: "#effafe",
        colorFront: "#bf40a0",
        density: 0.9,
        strokeWidth: 0.75,
        strokeCap: 1,
        strokeTaper: 0.18,
        noise: 0.74,
        noiseFrequency: 0.33,
        softness: 0.02
      )
    ),
    Preset(
      name: "Swirl",
      params: Params(
        colorBack: "#b3e6d9",
        colorFront: "#1a2b4d",
        density: 0.2,
        noiseFrequency: 0.3,
        softness: 0.5,
        sizing: ShaderSizingParams(fit: .none, scale: 0.45)
      )
    ),
  ]

  static let source = """

  struct SpiralUniforms {
    float4 u_colorBack;
    float4 u_colorFront;
    float u_density;
    float u_distortion;
    float u_strokeWidth;
    float u_strokeCap;
    float u_strokeTaper;
    float u_noise;
    float u_noiseFrequency;
    float u_softness;
  };

  fragment float4 ps_fragment(PSVertexOut in [[stage_in]],
                              constant PSGlobalUniforms& global [[buffer(0)]],
                              constant SpiralUniforms& u [[buffer(1)]]) {
    float2 uv = 2. * in.patternUV;

    float t = global.u_time;
    float l = length(uv);
    float density = clamp(u.u_density, 0., 1.);
    l = pow(max(l, 1e-6), density);
    float angle = atan2(uv.y, uv.x) - t;
    float angleNormalised = angle / TWO_PI;

    angleNormalised += .125 * u.u_noise * snoise(16. * pow(u.u_noiseFrequency, 3.) * uv);

    float offset = l + angleNormalised;
    offset -= u.u_distortion * (sin(4. * l - .5 * t) * cos(PI + l + .5 * t));
    float stripe = fract(offset);

    float shape = 2. * abs(stripe - .5);
    float width = 1. - clamp(u.u_strokeWidth, .005 * u.u_strokeTaper, 1.);

    float wCap = mix(width, (1. - stripe) * (1. - step(.5, stripe)), (1. - clamp(l, 0., 1.)));
    width = mix(width, wCap, u.u_strokeCap);
    width *= (1. - clamp(u.u_strokeTaper, 0., 1.) * l);

    float fw = fwidth(offset);
    float fwMult = 4. - 3. * (smoothstep(.05, .4, 2. * u.u_strokeWidth) * smoothstep(.05, .4, 2. * (1. - u.u_strokeWidth)));
    float pixelSize = mix(fwMult * fw, fwidth(shape), clamp(fw, 0., 1.));
    pixelSize = mix(pixelSize, .002, u.u_strokeCap * (1. - clamp(l, 0., 1.)));

    float res = smoothstep(width - pixelSize - u.u_softness, width + pixelSize + u.u_softness, shape);

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
