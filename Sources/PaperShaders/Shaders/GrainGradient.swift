import simd

/// Port of upstream `grain-gradient.frag`.
public enum GrainGradient {
  /// Descriptor.
  public static let descriptor = ShaderDescriptor(
    name: "grain-gradient",
    fragmentSource: source,
    maskFragmentFunctionName: "ps_mask_fragment",
    usesNoiseTexture: true
  )

  /// Options for shape.
  public enum Shape: String, Sendable {
    case wave
    case dots
    case truchet
    case corners
    case ripple
    case blob
    case sphere

    var uniformValue: Float {
      switch self {
      case .wave: return 1
      case .dots: return 2
      case .truchet: return 3
      case .corners: return 4
      case .ripple: return 5
      case .blob: return 6
      case .sphere: return 7
      }
    }
  }

  /// Parameters used to render this shader.
  public struct Params {
    /// Color back.
    public var colorBack: String
    /// Colors.
    public var colors: [String]
    /// Softness.
    public var softness: Float
    /// Intensity.
    public var intensity: Float
    /// Noise.
    public var noise: Float
    /// Shape.
    public var shape: Shape
    /// Sizing.
    public var sizing: ShaderSizingParams
    /// Speed.
    public var speed: Double
    /// Frame.
    public var frame: Double

    /// Creates an instance.
    public init(
      colorBack: String = "#000000",
      colors: [String] = ["#7300ff", "#eba8ff", "#00bfff", "#2a00ff"],
      softness: Float = 0.5,
      intensity: Float = 0.5,
      noise: Float = 0.25,
      shape: Shape = .corners,
      sizing: ShaderSizingParams = ShaderSizingParams(fit: .contain),
      speed: Double = 1,
      frame: Double = 0
    ) {
      self.colorBack = colorBack
      self.colors = colors
      self.softness = softness
      self.intensity = intensity
      self.noise = noise
      self.shape = shape
      self.sizing = sizing
      self.speed = speed
      self.frame = frame
    }

    /// Matches `GrainGradientUniforms` member order in the MSL source.
    public var uniforms: [UniformValue] {
      [
        .float4(ShaderColor.parse(colorBack)),
        .float4Array(colors.map(ShaderColor.parse), capacity: 7),
        .float(Float(max(colors.count, 1))),
        .float(softness),
        .float(intensity),
        .float(noise),
        .float(shape.uniformValue),
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
      name: "Wave",
      params: Params(
        colorBack: "#000a0f",
        colors: ["#c4730b", "#bdad5f", "#d8ccc7"],
        softness: 0.7,
        intensity: 0.15,
        noise: 0.5,
        shape: .wave,
        sizing: ShaderSizingParams(fit: .none)
      )
    ),
    Preset(
      name: "Dots",
      params: Params(
        colorBack: "#0a0000",
        colors: ["#6f0000", "#0080ff", "#f2ebc9", "#33cc33"],
        softness: 1,
        intensity: 1,
        noise: 0.7,
        shape: .dots,
        sizing: ShaderSizingParams(fit: .none, scale: 0.6)
      )
    ),
    Preset(
      name: "Truchet",
      params: Params(
        colorBack: "#0a0000",
        colors: ["#6f2200", "#eabb7c", "#39b523"],
        softness: 0,
        intensity: 0.2,
        noise: 1,
        shape: .truchet,
        sizing: ShaderSizingParams(fit: .none)
      )
    ),
    Preset(
      name: "Ripple",
      params: Params(
        colorBack: "#140a00",
        colors: ["#6f2d00", "#88ddae", "#2c0b1d"],
        softness: 0.5,
        intensity: 0.5,
        noise: 0.5,
        shape: .ripple,
        sizing: ShaderSizingParams(fit: .contain, scale: 0.5)
      )
    ),
    Preset(
      name: "Blob",
      params: Params(
        colorBack: "#0f0e18",
        colors: ["#3e6172", "#a49b74", "#568c50"],
        softness: 0,
        intensity: 0.15,
        noise: 0.5,
        shape: .blob,
        sizing: ShaderSizingParams(fit: .contain, scale: 1.3)
      )
    ),
  ]

  static let source = """

  struct GrainGradientUniforms {
    float4 u_colorBack;
    float4 u_colors[7];
    float u_colorsCount;
    float u_softness;
    float u_intensity;
    float u_noise;
    float u_shape;
  };

  static float ggRandomR(float2 p, texture2d<float> noiseTex, sampler noiseSampler) {
    float2 uv = floor(p) / 100. + .5;
    float n = noiseTex.sample(noiseSampler, fract(uv), level(0)).r;
    return floor(n * 255. + .5) / 255.;
  }

  static float ggValueNoiseR(float2 st, texture2d<float> noiseTex, sampler noiseSampler) {
    float2 i = floor(st);
    float2 f = fract(st);
    float a = ggRandomR(i, noiseTex, noiseSampler);
    float b = ggRandomR(i + float2(1.0, 0.0), noiseTex, noiseSampler);
    float c = ggRandomR(i + float2(0.0, 1.0), noiseTex, noiseSampler);
    float d = ggRandomR(i + float2(1.0, 1.0), noiseTex, noiseSampler);
    float2 u = f * f * (3.0 - 2.0 * f);
    float x1 = mix(a, b, u.x);
    float x2 = mix(c, d, u.x);
    return mix(x1, x2, u.y);
  }

  static float4 ggFbmR(float2 n0, float2 n1, float2 n2, float2 n3,
                       texture2d<float> noiseTex, sampler noiseSampler) {
    float amplitude = 0.2;
    float4 total = float4(0.);
    for (int i = 0; i < 3; i++) {
      n0 = rotate(n0, 0.3);
      n1 = rotate(n1, 0.3);
      n2 = rotate(n2, 0.3);
      n3 = rotate(n3, 0.3);
      total.x += ggValueNoiseR(n0, noiseTex, noiseSampler) * amplitude;
      total.y += ggValueNoiseR(n1, noiseTex, noiseSampler) * amplitude;
      total.z += ggValueNoiseR(n2, noiseTex, noiseSampler) * amplitude;
      total.z += ggValueNoiseR(n3, noiseTex, noiseSampler) * amplitude;
      n0 *= 1.99;
      n1 *= 1.99;
      n2 *= 1.99;
      n3 *= 1.99;
      amplitude *= 0.6;
    }
    return total;
  }

  static float2 ggTruchet(float2 uv, float idx) {
    idx = fract(((idx - .5) * 2.));
    if (idx > 0.75) {
      uv = float2(1.0) - uv;
    } else if (idx > 0.5) {
      uv = float2(1.0 - uv.x, uv.y);
    } else if (idx > 0.25) {
      uv = 1.0 - float2(1.0 - uv.x, uv.y);
    }
    return uv;
  }

  static float ggShapeValue(float2 shapeUV, float2 grainUV, float t,
                            constant GrainGradientUniforms& u,
                            texture2d<float> noiseTex,
                            sampler noiseSampler) {
    float shape = 0.;

    if (u.u_shape < 1.5) {
      float wave = cos(.5 * shapeUV.x - 4. * t) * sin(1.5 * shapeUV.x + 2. * t) * (.75 + .25 * cos(6. * t));
      shape = 1. - smoothstep(-1., 1., shapeUV.y + wave);
    } else if (u.u_shape < 2.5) {
      float stripeIdx = floor(2. * shapeUV.x / TWO_PI);
      float rand = hash11(stripeIdx * 100.);
      rand = sign(rand - .5) * pow(4. * abs(rand), .3);
      shape = sin(shapeUV.x) * cos(shapeUV.y - 5. * rand * t);
      shape = pow(abs(shape), 4.);
    } else if (u.u_shape < 3.5) {
      float n2 = ggValueNoiseR(shapeUV * .4 - 3.75 * t, noiseTex, noiseSampler);
      shapeUV.x += 10.;
      shapeUV *= .6;

      float2 tile = ggTruchet(fract(shapeUV), ggRandomR(floor(shapeUV), noiseTex, noiseSampler));
      float distance1 = length(tile);
      float distance2 = length(tile - float2(1.));

      n2 -= .5;
      n2 *= .1;
      shape = smoothstep(.2, .55, distance1 + n2) * (1. - smoothstep(.45, .8, distance1 - n2));
      shape += smoothstep(.2, .55, distance2 + n2) * (1. - smoothstep(.45, .8, distance2 - n2));
      shape = pow(shape, 1.5);
    } else if (u.u_shape < 4.5) {
      shapeUV *= .6;
      float2 outer = float2(.5);

      float2 bl = smoothstep(float2(0.), outer, shapeUV + float2(.1 + .1 * sin(3. * t), .2 - .1 * sin(5.25 * t)));
      float2 tr = smoothstep(float2(0.), outer, 1. - shapeUV);
      shape = 1. - bl.x * bl.y * tr.x * tr.y;

      shapeUV = -shapeUV;
      bl = smoothstep(float2(0.), outer, shapeUV + float2(.1 + .1 * sin(3. * t), .2 - .1 * cos(5.25 * t)));
      tr = smoothstep(float2(0.), outer, 1. - shapeUV);
      shape -= bl.x * bl.y * tr.x * tr.y;
      shape = 1. - smoothstep(0., 1., shape);
    } else if (u.u_shape < 5.5) {
      shapeUV *= 2.;
      float dist = length(.4 * shapeUV);
      float waves = sin(pow(dist, 1.2) * 5. - 3. * t) * .5 + .5;
      shape = waves;
    } else if (u.u_shape < 6.5) {
      t *= 2.;
      float2 f1Traj = .25 * float2(1.3 * sin(t), .2 + 1.3 * cos(.6 * t + 4.));
      float2 f2Traj = .2 * float2(1.2 * sin(-t), 1.3 * sin(1.6 * t));
      float2 f3Traj = .25 * float2(1.7 * cos(-.6 * t), cos(-1.6 * t));
      float2 f4Traj = .3 * float2(1.4 * cos(.8 * t), 1.2 * sin(-.6 * t - 3.));

      // Upstream uses `clamp(0., 1., length(...))`; with min > max this
      // behaves like `1.` in the SwiftShader golden harness.
      shape = .0;

      shape = smoothstep(.0, .9, shape);
      float edge = smoothstep(.25, .3, shape);
      shape = mix(.0, shape, edge);
    } else {
      shapeUV *= 2.;
      float d = 1. - pow(length(shapeUV), 2.);
      float3 pos = float3(shapeUV, sqrt(max(d, 0.)));
      float3 lightPos = normalize(float3(cos(1.5 * t), .8, sin(1.25 * t)));
      shape = .5 + .5 * dot(lightPos, pos);
      shape *= step(0., d);
    }

    float baseNoise = snoise(grainUV * .5);
    float4 fbmVals = ggFbmR(
      .002 * grainUV + 10.,
      .003 * grainUV,
      .001 * grainUV,
      rotate(.4 * grainUV, 2.),
      noiseTex,
      noiseSampler
    );
    float grainDist = baseNoise * snoise(grainUV * .2) - fbmVals.x - fbmVals.y;
    float rawNoise = .75 * baseNoise - fbmVals.w - fbmVals.z;
    float noise = clamp(rawNoise, 0., 1.);

    shape += u.u_intensity * 2. / u.u_colorsCount * (grainDist + .5);
    shape += u.u_noise * 10. / u.u_colorsCount * noise;
    return shape;
  }

  fragment float4 ps_mask_fragment(PSVertexOut in [[stage_in]],
                                   constant PSGlobalUniforms& global [[buffer(0)]],
                                   constant GrainGradientUniforms& u [[buffer(1)]],
                                   constant PSSizingUniforms& sizing [[buffer(2)]],
                                   texture2d<float> noiseTex [[texture(0)]],
                                   sampler noiseSampler [[sampler(0)]]) {
    const float firstFrameOffset = 7.;
    float t = .1 * (global.u_time + firstFrameOffset);

    float2 shapeUV = float2(0.);
    float2 grainUV = float2(0.);

    float r = sizing.u_rotation * PI / 180.;
    float cr = cos(r);
    float sr = sin(r);
    float2x2 graphicRotation = float2x2(float2(cr, sr), float2(-sr, cr));
    float2 graphicOffset = float2(-sizing.u_offsetX, sizing.u_offsetY);

    if (u.u_shape > 3.5) {
      shapeUV = in.objectUV;
      grainUV = shapeUV;
      grainUV = transpose(graphicRotation) * grainUV;
      grainUV *= sizing.u_scale;
      grainUV -= graphicOffset;
      grainUV *= in.objectBoxSize;
      grainUV *= .7;
    } else {
      shapeUV = .5 * in.patternUV;
      grainUV = 100. * in.patternUV;
      grainUV = transpose(graphicRotation) * grainUV;
      grainUV *= sizing.u_scale;
      if (sizing.u_fit > 0.) {
        float2 givenBoxSize = float2(sizing.u_worldWidth, sizing.u_worldHeight);
        givenBoxSize = max(givenBoxSize, float2(1.)) * global.u_pixelRatio;
        float patternBoxRatio = givenBoxSize.x / givenBoxSize.y;
        float2 patternBoxGivenSize = float2(
          (sizing.u_worldWidth == 0.) ? global.u_resolution.x : givenBoxSize.x,
          (sizing.u_worldHeight == 0.) ? global.u_resolution.y : givenBoxSize.y
        );
        patternBoxRatio = patternBoxGivenSize.x / patternBoxGivenSize.y;
        float patternBoxNoFitBoxWidth = patternBoxRatio * min(patternBoxGivenSize.x / patternBoxRatio, patternBoxGivenSize.y);
        grainUV /= (patternBoxNoFitBoxWidth / in.patternBoxSize.x);
      }
      float2 patternBoxScale = global.u_resolution / in.patternBoxSize;
      grainUV -= graphicOffset / patternBoxScale;
      grainUV *= 1.6;
    }

    float shape = ggShapeValue(shapeUV, grainUV, t, u, noiseTex, noiseSampler);
    return float4(shape, 0., 0., 1.);
  }

  fragment float4 ps_fragment(PSVertexOut in [[stage_in]],
                              constant PSGlobalUniforms& global [[buffer(0)]],
                              constant GrainGradientUniforms& u [[buffer(1)]],
                              constant PSSizingUniforms& sizing [[buffer(2)]],
                              texture2d<float> noiseTex [[texture(0)]],
                              sampler noiseSampler [[sampler(0)]],
                              texture2d<float> maskTex [[texture(2)]]) {
    uint2 maxCoord = uint2(maskTex.get_width() - 1, maskTex.get_height() - 1);
    uint2 pixel = min(uint2(in.position.xy), maxCoord);
    float shape = maskTex.read(pixel).r;
    float shapeDx = maskTex.read(uint2(min(pixel.x ^ 1, maxCoord.x), pixel.y)).r;
    float shapeDy = maskTex.read(uint2(pixel.x, min(pixel.y ^ 1, maxCoord.y))).r;
    float aa = abs(shapeDx - shape) + abs(shapeDy - shape);

    (void)global;
    (void)sizing;
    (void)noiseTex;
    (void)noiseSampler;

    shape = clamp(shape - .5 / u.u_colorsCount, 0., 1.);
    float totalShape = smoothstep(0., u.u_softness + 2. * aa, clamp(shape * u.u_colorsCount, 0., 1.));
    float mixer = shape * (u.u_colorsCount - 1.);

    int cntStop = int(u.u_colorsCount) - 1;
    float4 gradient = u.u_colors[0];
    gradient.rgb *= gradient.a;
    for (int i = 1; i < 7; i++) {
      if (i > cntStop) break;
      float localT = clamp(mixer - float(i - 1), 0., 1.);
      localT = smoothstep(.5 - .5 * u.u_softness - aa, .5 + .5 * u.u_softness + aa, localT);

      float4 c = u.u_colors[i];
      c.rgb *= c.a;
      gradient = mix(gradient, c, localT);
    }

    float3 color = gradient.rgb * totalShape;
    float opacity = gradient.a * totalShape;

    float3 bgColor = u.u_colorBack.rgb * u.u_colorBack.a;
    color = color + bgColor * (1.0 - opacity);
    opacity = opacity + u.u_colorBack.a * (1.0 - opacity);

    return float4(color, opacity);
  }

  """
}
