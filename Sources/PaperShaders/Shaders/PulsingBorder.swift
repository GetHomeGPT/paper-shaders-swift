import simd

/// Port of upstream `pulsing-border.frag`.
public enum PulsingBorder {
  /// Descriptor.
  public static let descriptor = ShaderDescriptor(
    name: "pulsing-border",
    fragmentSource: source,
    usesNoiseTexture: true
  )

  /// Options for aspect ratio.
  public enum AspectRatio: String, Sendable {
    case auto
    case square

    var uniformValue: Float {
      switch self {
      case .auto: return 0
      case .square: return 1
      }
    }
  }

  /// Parameters used to render this shader.
  public struct Params {
    /// Colors.
    public var colors: [String]
    /// Color back.
    public var colorBack: String
    /// Roundness.
    public var roundness: Float
    /// Thickness.
    public var thickness: Float
    /// Margin left.
    public var marginLeft: Float
    /// Margin right.
    public var marginRight: Float
    /// Margin top.
    public var marginTop: Float
    /// Margin bottom.
    public var marginBottom: Float
    /// Aspect ratio.
    public var aspectRatio: AspectRatio
    /// Softness.
    public var softness: Float
    /// Intensity.
    public var intensity: Float
    /// Bloom.
    public var bloom: Float
    /// Spots.
    public var spots: Float
    /// Spot size.
    public var spotSize: Float
    /// Pulse.
    public var pulse: Float
    /// Smoke.
    public var smoke: Float
    /// Smoke size.
    public var smokeSize: Float
    /// Sizing.
    public var sizing: ShaderSizingParams
    /// Speed.
    public var speed: Double
    /// Frame.
    public var frame: Double

    /// Creates an instance.
    public init(
      colors: [String] = ["#0dc1fd", "#d915ef", "#ff3f2ecc"],
      colorBack: String = "#000000",
      roundness: Float = 0.25,
      thickness: Float = 0.1,
      marginLeft: Float = 0,
      marginRight: Float = 0,
      marginTop: Float = 0,
      marginBottom: Float = 0,
      aspectRatio: AspectRatio = .auto,
      softness: Float = 0.75,
      intensity: Float = 0.2,
      bloom: Float = 0.25,
      spots: Float = 5,
      spotSize: Float = 0.5,
      pulse: Float = 0.25,
      smoke: Float = 0.3,
      smokeSize: Float = 0.6,
      sizing: ShaderSizingParams = ShaderSizingParams(fit: .contain, scale: 0.6),
      speed: Double = 1,
      frame: Double = 0
    ) {
      self.colors = colors
      self.colorBack = colorBack
      self.roundness = roundness
      self.thickness = thickness
      self.marginLeft = marginLeft
      self.marginRight = marginRight
      self.marginTop = marginTop
      self.marginBottom = marginBottom
      self.aspectRatio = aspectRatio
      self.softness = softness
      self.intensity = intensity
      self.bloom = bloom
      self.spots = spots
      self.spotSize = spotSize
      self.pulse = pulse
      self.smoke = smoke
      self.smokeSize = smokeSize
      self.sizing = sizing
      self.speed = speed
      self.frame = frame
    }

    /// Matches `PulsingBorderUniforms` member order in the MSL source.
    public var uniforms: [UniformValue] {
      [
        .float4(ShaderColor.parse(colorBack)),
        .float4Array(colors.map(ShaderColor.parse), capacity: 5),
        .float(Float(max(colors.count, 1))),
        .float(roundness),
        .float(thickness),
        .float(marginLeft),
        .float(marginRight),
        .float(marginTop),
        .float(marginBottom),
        .float(aspectRatio.uniformValue),
        .float(softness),
        .float(intensity),
        .float(bloom),
        .float(spotSize),
        .float(spots),
        .float(pulse),
        .float(smoke),
        .float(smokeSize),
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
      name: "Circle",
      params: Params(
        roundness: 1,
        thickness: 0,
        aspectRatio: .square,
        softness: 0.75,
        intensity: 0.2,
        bloom: 0.45,
        spots: 3,
        spotSize: 0.4,
        pulse: 0.5,
        smoke: 1,
        smokeSize: 0,
        sizing: ShaderSizingParams(fit: .contain, scale: 0.6)
      )
    ),
    Preset(
      name: "Northern lights",
      params: Params(
        colors: ["#4c4794", "#774a7d", "#12694a", "#0aff78", "#4733cc"],
        colorBack: "#0c182c",
        roundness: 0,
        thickness: 1,
        softness: 1,
        intensity: 0.1,
        bloom: 0.2,
        spots: 4,
        spotSize: 0.25,
        pulse: 0,
        smoke: 0.32,
        smokeSize: 0.5,
        sizing: ShaderSizingParams(fit: .contain, scale: 1.1),
        speed: 0.18
      )
    ),
    Preset(
      name: "Solid line",
      params: Params(
        colors: ["#81ADEC"],
        colorBack: "#00000000",
        roundness: 0,
        thickness: 0.05,
        softness: 0,
        intensity: 0,
        bloom: 0.15,
        spots: 4,
        spotSize: 1,
        pulse: 0,
        smoke: 0,
        smokeSize: 0,
        sizing: ShaderSizingParams(fit: .contain)
      )
    ),
  ]

  static let source = """

  struct PulsingBorderUniforms {
    float4 u_colorBack;
    float4 u_colors[5];
    float u_colorsCount;
    float u_roundness;
    float u_thickness;
    float u_marginLeft;
    float u_marginRight;
    float u_marginTop;
    float u_marginBottom;
    float u_aspectRatio;
    float u_softness;
    float u_intensity;
    float u_bloom;
    float u_spotSize;
    float u_spots;
    float u_pulse;
    float u_smoke;
    float u_smokeSize;
  };

  static float pbBeat(float time) {
    float first = pow(abs(sin(time * TWO_PI)), 10.);
    float second = pow(abs(sin((time - .15) * TWO_PI)), 10.);
    return clamp(first + 0.6 * second, 0.0, 1.0);
  }

  static float pbSst(float edge0, float edge1, float x) {
    return smoothstep(edge0, edge1, x);
  }

  static float pbRoundedBox(float2 uv, float2 halfSize, float distance, float cornerDistance,
                            float thickness, float softness) {
    float borderDistance = abs(distance);
    float aa = 2. * fwidth(distance);
    float border = 1. - pbSst(min(mix(thickness, -thickness, softness), thickness + aa),
                              max(mix(thickness, -thickness, softness), thickness + aa),
                              borderDistance);
    float cornerFadeCircles = 0.;
    cornerFadeCircles = mix(1., cornerFadeCircles, pbSst(0., 1., length((uv + halfSize) / thickness)));
    cornerFadeCircles = mix(1., cornerFadeCircles, pbSst(0., 1., length((uv - float2(-halfSize.x, halfSize.y)) / thickness)));
    cornerFadeCircles = mix(1., cornerFadeCircles, pbSst(0., 1., length((uv - float2(halfSize.x, -halfSize.y)) / thickness)));
    cornerFadeCircles = mix(1., cornerFadeCircles, pbSst(0., 1., length((uv - halfSize) / thickness)));
    aa = fwidth(cornerDistance);
    float cornerFade = pbSst(0., mix(aa, thickness, softness), cornerDistance);
    cornerFade *= cornerFadeCircles;
    border += cornerFade;
    return border;
  }

  static float2 pbRandomGB(float2 p, texture2d<float> noiseTex, sampler noiseSampler) {
    float2 uv = floor(p) / 100. + .5;
    return noiseTex.sample(noiseSampler, fract(uv)).gb;
  }

  static float pbRandomG(float2 p, texture2d<float> noiseTex, sampler noiseSampler) {
    float2 uv = floor(p) / 100. + .5;
    return noiseTex.sample(noiseSampler, fract(uv)).g;
  }

  static float pbValueNoise(float2 st, texture2d<float> noiseTex, sampler noiseSampler) {
    float2 i = floor(st);
    float2 f = fract(st);
    float a = pbRandomG(i, noiseTex, noiseSampler);
    float b = pbRandomG(i + float2(1.0, 0.0), noiseTex, noiseSampler);
    float c = pbRandomG(i + float2(0.0, 1.0), noiseTex, noiseSampler);
    float d = pbRandomG(i + float2(1.0, 1.0), noiseTex, noiseSampler);
    float2 u = f * f * (3.0 - 2.0 * f);
    float x1 = mix(a, b, u.x);
    float x2 = mix(c, d, u.x);
    return mix(x1, x2, u.y);
  }

  fragment float4 ps_fragment(PSVertexOut in [[stage_in]],
                              constant PSGlobalUniforms& global [[buffer(0)]],
                              constant PulsingBorderUniforms& u [[buffer(1)]],
                              texture2d<float> noiseTex [[texture(0)]],
                              sampler noiseSampler [[sampler(0)]]) {
    const float firstFrameOffset = 109.;
    float t = 1.2 * (global.u_time + firstFrameOffset);

    float2 borderUV = in.responsiveUV;
    float pulse = u.u_pulse * pbBeat(.18 * global.u_time);

    float canvasRatio = in.responsiveBoxGivenSize.x / in.responsiveBoxGivenSize.y;
    float2 halfSize = float2(.5);
    borderUV.x *= max(canvasRatio, 1.);
    borderUV.y /= min(canvasRatio, 1.);
    halfSize.x *= max(canvasRatio, 1.);
    halfSize.y /= min(canvasRatio, 1.);

    float mL = u.u_marginLeft;
    float mR = u.u_marginRight;
    float mT = u.u_marginTop;
    float mB = u.u_marginBottom;
    float mX = mL + mR;
    float mY = mT + mB;

    if (u.u_aspectRatio > 0.) {
      float shapeRatio = canvasRatio * (1. - mX) / max(1. - mY, 1e-6);
      float freeX = shapeRatio > 1. ? (1. - mX) * (1. - 1. / max(abs(shapeRatio), 1e-6)) : 0.;
      float freeY = shapeRatio < 1. ? (1. - mY) * (1. - shapeRatio) : 0.;
      mL += freeX * 0.5;
      mR += freeX * 0.5;
      mT += freeY * 0.5;
      mB += freeY * 0.5;
      mX = mL + mR;
      mY = mT + mB;
    }

    float thickness = .5 * u.u_thickness * min(halfSize.x, halfSize.y);

    halfSize.x *= (1. - mX);
    halfSize.y *= (1. - mY);

    float2 centerShift = float2(
      (mL - mR) * max(canvasRatio, 1.) * 0.5,
      (mB - mT) / min(canvasRatio, 1.) * 0.5
    );

    borderUV -= centerShift;
    halfSize -= mix(thickness, 0., u.u_softness);

    float radius = mix(0., min(halfSize.x, halfSize.y), u.u_roundness);
    float2 d = abs(borderUV) - halfSize + radius;
    float outsideDistance = length(max(d, .0001)) - radius;
    float insideDistance = min(max(d.x, d.y), .0001);
    float cornerDistance = abs(min(max(d.x, d.y) - .45 * radius, .0));
    float distance = outsideDistance + insideDistance;

    float borderThickness = mix(thickness, 3. * thickness, u.u_softness);
    float border = pbRoundedBox(borderUV, halfSize, distance, cornerDistance, borderThickness, u.u_softness);
    border = pow(border, 1. + u.u_softness);

    float2 smokeUV = .3 * u.u_smokeSize * in.patternUV;
    float smoke = clamp(3. * pbValueNoise(2.7 * smokeUV + .5 * t, noiseTex, noiseSampler), 0., 1.);
    smoke -= pbValueNoise(3.4 * smokeUV - .5 * t, noiseTex, noiseSampler);
    float smokeThickness = thickness + .2;
    smokeThickness = min(.4, max(smokeThickness, .1));
    smoke *= pbRoundedBox(borderUV, halfSize, distance, cornerDistance, smokeThickness, 1.);
    smoke = 30. * smoke * smoke;
    smoke *= mix(0., .5, pow(u.u_smoke, 2.));
    smoke *= mix(1., pulse, u.u_pulse);
    smoke = clamp(smoke, 0., 1.);
    border += smoke;

    border = clamp(border, 0., 1.);

    float3 blendColor = float3(0.);
    float blendAlpha = 0.;
    float3 addColor = float3(0.);
    float addAlpha = 0.;

    float bloom = 4. * u.u_bloom;
    float intensity = 1. + (1. + 4. * u.u_softness) * u.u_intensity;

    float angle = atan2(borderUV.y, borderUV.x) / TWO_PI;

    for (int colorIdx = 0; colorIdx < 5; colorIdx++) {
      if (colorIdx >= int(u.u_colorsCount)) break;
      float colorIdxF = float(colorIdx);

      float3 c = u.u_colors[colorIdx].rgb * u.u_colors[colorIdx].a;
      float a = u.u_colors[colorIdx].a;

      for (int spotIdx = 0; spotIdx < 4; spotIdx++) {
        if (spotIdx >= int(u.u_spots)) break;
        float spotIdxF = float(spotIdx);

        float2 randVal = pbRandomGB(float2(spotIdxF * 10. + 2., 40. + colorIdxF), noiseTex, noiseSampler);

        float time = (.1 + .15 * abs(sin(spotIdxF * (2. + colorIdxF)) * cos(spotIdxF * (2. + 2.5 * colorIdxF)))) * t + randVal.x * 3.;
        time *= mix(1., -1., step(.5, randVal.y));

        float mask = .5 + .5 * mix(
          sin(t + spotIdxF * (5. - 1.5 * colorIdxF)),
          cos(t + spotIdxF * (3. + 1.3 * colorIdxF)),
          step(glsl_mod(colorIdxF, 2.), .5)
        );

        float p = clamp(2. * u.u_pulse - randVal.x, 0., 1.);
        mask = mix(mask, pulse, p);

        float atg1 = fract(angle + time);
        float spotSize = .05 + .6 * pow(u.u_spotSize, 2.) + .05 * randVal.x;
        spotSize = mix(spotSize, .1, p);
        float sector = pbSst(.5 - spotSize, .5, atg1) * (1. - pbSst(.5, .5 + spotSize, atg1));

        sector *= mask;
        sector *= border;
        sector *= intensity;
        sector = clamp(sector, 0., 1.);

        float3 srcColor = c * sector;
        float srcAlpha = a * sector;

        blendColor += ((1. - blendAlpha) * srcColor);
        blendAlpha = blendAlpha + (1. - blendAlpha) * srcAlpha;
        addColor += srcColor;
        addAlpha += srcAlpha;
      }
    }

    float3 accumColor = mix(blendColor, addColor, bloom);
    float accumAlpha = mix(blendAlpha, addAlpha, bloom);
    accumAlpha = clamp(accumAlpha, 0., 1.);

    float3 bgColor = u.u_colorBack.rgb * u.u_colorBack.a;
    float3 color = accumColor + (1. - accumAlpha) * bgColor;
    float opacity = accumAlpha + (1. - accumAlpha) * u.u_colorBack.a;

    float2 fragCoordGL = float2(in.position.x, global.u_resolution.y - in.position.y);
    color += 1. / 256. * (fract(sin(dot(.014 * fragCoordGL, float2(12.9898, 78.233))) * 43758.5453123) - .5);

    return float4(color, opacity);
  }

  """
}
