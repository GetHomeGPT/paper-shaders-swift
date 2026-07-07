import simd

/// Port of upstream `neuro-noise.frag`.
public enum NeuroNoise {
  /// Descriptor.
  public static let descriptor = ShaderDescriptor(
    name: "neuro-noise",
    fragmentSource: source
  )

  /// Parameters used to render this shader.
  public struct Params {
    /// Color front.
    public var colorFront: String
    /// Color mid.
    public var colorMid: String
    /// Color back.
    public var colorBack: String
    /// Brightness.
    public var brightness: Float
    /// Contrast.
    public var contrast: Float
    /// Sizing.
    public var sizing: ShaderSizingParams
    /// Speed.
    public var speed: Double
    /// Frame.
    public var frame: Double

    /// Creates an instance.
    public init(
      colorFront: String = "#ffffff",
      colorMid: String = "#47a6ff",
      colorBack: String = "#000000",
      brightness: Float = 0.05,
      contrast: Float = 0.3,
      sizing: ShaderSizingParams = .defaultPattern,
      speed: Double = 1,
      frame: Double = 0
    ) {
      self.colorFront = colorFront
      self.colorMid = colorMid
      self.colorBack = colorBack
      self.brightness = brightness
      self.contrast = contrast
      self.sizing = sizing
      self.speed = speed
      self.frame = frame
    }

    /// Matches `NeuroNoiseUniforms` member order in the MSL source.
    public var uniforms: [UniformValue] {
      [
        .float4(ShaderColor.parse(colorFront)),
        .float4(ShaderColor.parse(colorMid)),
        .float4(ShaderColor.parse(colorBack)),
        .float(brightness),
        .float(contrast),
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
      name: "Sensation",
      params: Params(
        colorFront: "#00c8ff",
        colorMid: "#fbff00",
        colorBack: "#8b42ff",
        brightness: 0.19,
        contrast: 0.12,
        sizing: ShaderSizingParams(fit: .none, scale: 3)
      )
    ),
    Preset(
      name: "Bloodstream",
      params: Params(
        colorFront: "#ff0000",
        colorMid: "#ff0000",
        colorBack: "#ffffff",
        brightness: 0.24,
        contrast: 0.17,
        sizing: ShaderSizingParams(fit: .none, scale: 0.7)
      )
    ),
    Preset(
      name: "Ghost",
      params: Params(
        colorFront: "#ffffff",
        colorMid: "#000000",
        colorBack: "#ffffff",
        brightness: 0,
        contrast: 1,
        sizing: ShaderSizingParams(fit: .none, scale: 0.55)
      )
    ),
  ]

  static let source = """

  struct NeuroNoiseUniforms {
    float4 u_colorFront;
    float4 u_colorMid;
    float4 u_colorBack;
    float u_brightness;
    float u_contrast;
  };

  static float neuroShape(float2 uv, float t) {
    float2 sine_acc = float2(0.);
    float2 res = float2(0.);
    float scale = 8.;

    for (int j = 0; j < 15; j++) {
      uv = rotate(uv, 1.);
      sine_acc = rotate(sine_acc, 1.);
      float2 layer = uv * scale + float(j) + sine_acc - t;
      sine_acc += sin(layer);
      res += (.5 + .5 * cos(layer)) / scale;
      scale *= (1.2);
    }
    return res.x + res.y;
  }

  fragment float4 ps_fragment(PSVertexOut in [[stage_in]],
                              constant PSGlobalUniforms& global [[buffer(0)]],
                              constant NeuroNoiseUniforms& u [[buffer(1)]]) {
    float2 shape_uv = in.patternUV;
    shape_uv *= .13;

    float t = .5 * global.u_time;

    float noise = neuroShape(shape_uv, t);

    noise = (1. + u.u_brightness) * noise * noise;
    noise = pow(noise, .7 + 6. * u.u_contrast);
    noise = min(1.4, noise);

    float blend = smoothstep(0.7, 1.4, noise);

    float4 frontC = u.u_colorFront;
    frontC.rgb *= frontC.a;
    float4 midC = u.u_colorMid;
    midC.rgb *= midC.a;
    float4 blendFront = mix(midC, frontC, blend);

    float safeNoise = max(noise, 0.0);
    float3 color = blendFront.rgb * safeNoise;
    float opacity = clamp(blendFront.a * safeNoise, 0., 1.);

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
