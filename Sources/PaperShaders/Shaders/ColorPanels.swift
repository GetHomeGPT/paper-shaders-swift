import simd

/// Port of upstream `color-panels.frag`.
public enum ColorPanels {
  /// Descriptor.
  public static let descriptor = ShaderDescriptor(
    name: "color-panels",
    fragmentSource: source
  )

  /// Parameters used to render this shader.
  public struct Params {
    /// Colors.
    public var colors: [String]
    /// Color back.
    public var colorBack: String
    /// Density.
    public var density: Float
    /// Angle1.
    public var angle1: Float
    /// Angle2.
    public var angle2: Float
    /// Length.
    public var length: Float
    /// Edges.
    public var edges: Bool
    /// Blur.
    public var blur: Float
    /// Fade in.
    public var fadeIn: Float
    /// Fade out.
    public var fadeOut: Float
    /// Gradient.
    public var gradient: Float
    /// Sizing.
    public var sizing: ShaderSizingParams
    /// Speed.
    public var speed: Double
    /// Frame.
    public var frame: Double

    /// Creates an instance.
    public init(
      colors: [String] = ["#ff9d00", "#fd4f30", "#809bff", "#6d2eff", "#333aff", "#f15cff", "#ffd557"],
      colorBack: String = "#000000",
      density: Float = 3,
      angle1: Float = 0,
      angle2: Float = 0,
      length: Float = 1.1,
      edges: Bool = false,
      blur: Float = 0,
      fadeIn: Float = 1,
      fadeOut: Float = 0.3,
      gradient: Float = 0,
      sizing: ShaderSizingParams = ShaderSizingParams(fit: .contain, scale: 0.8),
      speed: Double = 0.5,
      frame: Double = 0
    ) {
      self.colors = colors
      self.colorBack = colorBack
      self.density = density
      self.angle1 = angle1
      self.angle2 = angle2
      self.length = length
      self.edges = edges
      self.blur = blur
      self.fadeIn = fadeIn
      self.fadeOut = fadeOut
      self.gradient = gradient
      self.sizing = sizing
      self.speed = speed
      self.frame = frame
    }

    /// Matches `ColorPanelsUniforms` member order in the MSL source.
    /// Upstream passes the sizing `scale` prop as the `u_scale` uniform too.
    public var uniforms: [UniformValue] {
      [
        .float(sizing.scale),
        .float4Array(colors.map(ShaderColor.parse), capacity: 7),
        // Clamped to 1: the shader indexes with `idx % colorsCount`,
        // a zero count would be a modulo by zero.
        .float(Float(max(colors.count, 1))),
        .float4(ShaderColor.parse(colorBack)),
        .float(density),
        .float(angle1),
        .float(angle2),
        .float(length),
        .float(edges ? 1 : 0),
        .float(blur),
        .float(fadeIn),
        .float(fadeOut),
        .float(gradient),
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
      name: "Glass",
      params: Params(
        colors: ["#00cfff", "#ff2d55", "#34c759", "#af52de"],
        colorBack: "#ffffff00",
        density: 1.6,
        angle1: 0.3,
        angle2: 0.3,
        length: 1,
        edges: true,
        blur: 0.25,
        fadeIn: 0.85,
        fadeOut: 0.3,
        sizing: ShaderSizingParams(fit: .contain, rotation: 112),
        speed: 1
      )
    ),
    Preset(
      name: "Gradient",
      params: Params(
        colors: ["#f2ff00", "#00000000", "#00000000", "#5a0283", "#005eff"],
        colorBack: "#8ffff2",
        density: 1.65,
        angle1: 0.4,
        angle2: 0.4,
        length: 3,
        blur: 0.5,
        fadeIn: 1,
        fadeOut: 0.39,
        gradient: 0.78,
        sizing: ShaderSizingParams(fit: .contain, scale: 1.72, rotation: 270, offsetX: 0.18),
        speed: 0.5
      )
    ),
    Preset(
      name: "Opening",
      params: Params(
        colors: ["#00ffff"],
        colorBack: "#570044",
        density: 2.21,
        angle1: -1,
        angle2: -1,
        length: 0.52,
        fadeIn: 0,
        fadeOut: 1,
        sizing: ShaderSizingParams(fit: .contain, scale: 2.32, rotation: 360, offsetX: -0.3, offsetY: 0.6),
        speed: 2
      )
    ),
  ]

  static let source = """

  struct ColorPanelsUniforms {
    float u_scale;
    float4 u_colors[7];
    float u_colorsCount;
    float4 u_colorBack;
    float u_density;
    float u_angle1;
    float u_angle2;
    float u_length;
    float u_edges;
    float u_blur;
    float u_fadeIn;
    float u_fadeOut;
    float u_gradient;
  };

  constant float zLimit = .5;

  static float2 getPanel(float angle, float2 uv, float invLength, float aa,
                         constant ColorPanelsUniforms& u) {
    float sinA = sin(angle);
    float cosA = cos(angle);

    float denom = sinA - uv.y * cosA;
    if (abs(denom) < .01) return float2(0.);

    float z = uv.y / denom;

    if (z <= 0. || z > zLimit) return float2(0.);

    float zRatio = z / zLimit;
    float panelMap = 1. - zRatio;
    float x = uv.x * (cosA * z + 1.) * invLength;

    float zOffset = zRatio - .5;
    float left = -.5 + zOffset * u.u_angle1;
    float right = .5 - zOffset * u.u_angle2;
    float blurX = aa + 2. * panelMap * u.u_blur;

    float leftEdge1 = left - blurX;
    float leftEdge2 = left + .25 * blurX;
    float rightEdge1 = right - .25 * blurX;
    float rightEdge2 = right + blurX;

    float panel = smoothstep(leftEdge1, leftEdge2, x) * (1.0 - smoothstep(rightEdge1, rightEdge2, x));
    panel *= mix(0., panel, smoothstep(0., .01 / max(u.u_scale, 1e-6), panelMap));

    float midScreen = abs(sinA);
    if (u.u_edges > .5) {
      panelMap = mix(.99, panelMap, panel * clamp(panelMap / (.15 * (1. - pow(midScreen, .1))), 0.0, 1.0));
    } else if (midScreen < .07) {
      panel *= (midScreen * 15.);
    }

    return float2(panel, panelMap);
  }

  static float4 blendColor(float4 colorA, float panelMask, float panelMap,
                           constant ColorPanelsUniforms& u) {
    float fade = 1. - smoothstep(.97 - .97 * u.u_fadeIn, 1., panelMap);

    fade *= smoothstep(-.2 * (1. - u.u_fadeOut), u.u_fadeOut, panelMap);

    float3 blendedRGB = mix(float3(0.), colorA.rgb, fade);
    float blendedAlpha = mix(0., colorA.a, fade);

    return float4(blendedRGB, blendedAlpha) * panelMask;
  }

  fragment float4 ps_fragment(PSVertexOut in [[stage_in]],
                              constant PSGlobalUniforms& global [[buffer(0)]],
                              constant ColorPanelsUniforms& u [[buffer(1)]]) {
    float2 uv = in.objectUV;
    uv *= 1.25;

    float t = .02 * global.u_time;
    t = fract(t);
    bool reverseTime = (t < 0.5);

    float3 color = float3(0.);
    float opacity = 0.;

    float aa = .005 / u.u_scale;
    int colorsCount = int(u.u_colorsCount);

    float4 premultipliedColors[7];
    for (int i = 0; i < 7; i++) {
      if (i >= colorsCount) break;
      float4 c = u.u_colors[i];
      c.rgb *= c.a;
      premultipliedColors[i] = c;
    }

    float invLength = 1.5 / max(u.u_length, .001);

    int panelsNumber = 12;

    float densityNormalizer = 1.;
    if (colorsCount == 4) {
      panelsNumber = 16;
      densityNormalizer = 1.34;
    } else if (colorsCount == 5) {
      panelsNumber = 20;
      densityNormalizer = 1.67;
    } else if (colorsCount == 7) {
      panelsNumber = 14;
      densityNormalizer = 1.17;
    }

    float fPanelsNumber = float(panelsNumber);

    float panelGrad = 1. - clamp(u.u_gradient, 0., 1.);

    for (int set = 0; set < 2; set++) {
      bool isForward = (set == 0 && !reverseTime) || (set == 1 && reverseTime);
      if (!isForward) continue;

      for (int i = 0; i <= 20; i++) {
        if (i >= panelsNumber) break;

        int idx = panelsNumber - 1 - i;

        float offset = float(idx) / fPanelsNumber;
        if (set == 1) {
          offset += .5;
        }

        float densityFract = densityNormalizer * fract(t + offset);
        float angleNorm = densityFract / u.u_density;
        if (densityFract >= .5 || angleNorm >= .3) continue;

        float smoothDensity = clamp((.5 - densityFract) / .1, 0., 1.) * clamp(densityFract / .01, 0., 1.);
        float smoothAngle = clamp((.3 - angleNorm) / .05, 0., 1.);
        if (smoothDensity * smoothAngle < .001) continue;

        if (angleNorm > .5) {
          angleNorm = 0.5;
        }
        float2 panel = getPanel(angleNorm * TWO_PI + PI, uv, invLength, aa, u);
        if (panel[0] <= .001) continue;
        float panelMask = panel[0] * smoothDensity * smoothAngle;
        float panelMap = panel[1];

        int colorIdx = idx % colorsCount;
        int nextColorIdx = (idx + 1) % colorsCount;

        float4 colorA = premultipliedColors[colorIdx];
        float4 colorB = premultipliedColors[nextColorIdx];

        colorA = mix(colorA, colorB, max(0., smoothstep(.0, .45, panelMap) - panelGrad));
        float4 blended = blendColor(colorA, panelMask, panelMap, u);
        color = blended.rgb + color * (1. - blended.a);
        opacity = blended.a + opacity * (1. - blended.a);
      }

      for (int i = 0; i <= 20; i++) {
        if (i >= panelsNumber) break;

        int idx = panelsNumber - 1 - i;

        float offset = float(idx) / fPanelsNumber;
        if (set == 0) {
          offset += .5;
        }

        float densityFract = densityNormalizer * fract(-t + offset);
        float angleNorm = -densityFract / u.u_density;
        if (densityFract >= .5 || angleNorm < -.3) continue;

        float smoothDensity = clamp((.5 - densityFract) / .1, 0., 1.) * clamp(densityFract / .01, 0., 1.);
        float smoothAngle = clamp((angleNorm + .3) / .05, 0., 1.);
        if (smoothDensity * smoothAngle < .001) continue;

        float2 panel = getPanel(angleNorm * TWO_PI + PI, uv, invLength, aa, u);
        float panelMask = panel[0] * smoothDensity * smoothAngle;
        if (panelMask <= .001) continue;
        float panelMap = panel[1];

        int colorIdx = (colorsCount - (idx % colorsCount)) % colorsCount;
        if (colorIdx < 0) colorIdx += colorsCount;
        int nextColorIdx = (colorIdx + 1) % colorsCount;

        float4 colorA = premultipliedColors[colorIdx];
        float4 colorB = premultipliedColors[nextColorIdx];

        colorA = mix(colorA, colorB, max(0., smoothstep(.0, .45, panelMap) - panelGrad));
        float4 blended = blendColor(colorA, panelMask, panelMap, u);
        color = blended.rgb + color * (1. - blended.a);
        opacity = blended.a + opacity * (1. - blended.a);
      }
    }

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
