import simd

/// Port of upstream `halftone-dots.frag`.
public enum HalftoneDots {
  /// Descriptor.
  public static let descriptor = ShaderDescriptor(
    name: "halftone-dots",
    fragmentSource: source,
    usesImageTexture: true
  )

  /// Options for grid.
  public enum Grid: String, Sendable {
    case square
    case hex

    var uniformValue: Float {
      switch self {
      case .square: return 0
      case .hex: return 1
      }
    }
  }

  /// Options for dot type.
  public enum DotType: String, Sendable {
    case classic
    case gooey
    case holes
    case soft

    var uniformValue: Float {
      switch self {
      case .classic: return 0
      case .gooey: return 1
      case .holes: return 2
      case .soft: return 3
      }
    }
  }

  /// Parameters used to render this shader.
  public struct Params {
    /// Color front.
    public var colorFront: String
    /// Color back.
    public var colorBack: String
    /// Radius.
    public var radius: Float
    /// Contrast.
    public var contrast: Float
    /// Size.
    public var size: Float
    /// Grain mixer.
    public var grainMixer: Float
    /// Grain overlay.
    public var grainOverlay: Float
    /// Grain size.
    public var grainSize: Float
    /// Grid.
    public var grid: Grid
    /// Original colors.
    public var originalColors: Bool
    /// Inverted.
    public var inverted: Bool
    /// Type.
    public var type: DotType
    /// Sizing.
    public var sizing: ShaderSizingParams
    /// Speed.
    public var speed: Double
    /// Frame.
    public var frame: Double

    /// Creates an instance.
    public init(
      colorFront: String = "#2b2b2b",
      colorBack: String = "#f2f1e8",
      radius: Float = 1.25,
      contrast: Float = 0.4,
      size: Float = 0.5,
      grainMixer: Float = 0.2,
      grainOverlay: Float = 0.2,
      grainSize: Float = 0.5,
      grid: Grid = .hex,
      originalColors: Bool = false,
      inverted: Bool = false,
      type: DotType = .gooey,
      sizing: ShaderSizingParams = ShaderSizingParams(fit: .cover),
      speed: Double = 0,
      frame: Double = 0
    ) {
      self.colorFront = colorFront
      self.colorBack = colorBack
      self.radius = radius
      self.contrast = contrast
      self.size = size
      self.grainMixer = grainMixer
      self.grainOverlay = grainOverlay
      self.grainSize = grainSize
      self.grid = grid
      self.originalColors = originalColors
      self.inverted = inverted
      self.type = type
      self.sizing = sizing
      self.speed = speed
      self.frame = frame
    }

    /// Matches `HalftoneDotsUniforms` member order in the MSL source.
    public var uniforms: [UniformValue] {
      [
        .float4(ShaderColor.parse(colorFront)),
        .float4(ShaderColor.parse(colorBack)),
        .float(radius),
        .float(contrast),
        .float(size),
        .float(grainMixer),
        .float(grainOverlay),
        .float(grainSize),
        .float(grid.uniformValue),
        .float(originalColors ? 1 : 0),
        .float(inverted ? 1 : 0),
        .float(type.uniformValue),
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
      name: "LED screen",
      params: Params(
        colorFront: "#29ff7b",
        colorBack: "#000000",
        radius: 1.5,
        contrast: 0.3,
        grainMixer: 0,
        grainOverlay: 0,
        grid: .square,
        type: .soft
      )
    ),
    Preset(
      name: "Mosaic",
      params: Params(
        colorFront: "#b2aeae",
        colorBack: "#000000",
        radius: 2,
        contrast: 0.01,
        size: 0.6,
        grainMixer: 0,
        grainOverlay: 0,
        originalColors: true,
        type: .classic
      )
    ),
    Preset(
      name: "Round and square",
      params: Params(
        colorFront: "#ff8000",
        colorBack: "#141414",
        radius: 1,
        contrast: 1,
        size: 0.8,
        grainMixer: 0.05,
        grainOverlay: 0.3,
        grid: .square,
        inverted: true,
        type: .holes
      )
    ),
  ]

  static let source = """

  struct HalftoneDotsUniforms {
    float4 u_colorFront;
    float4 u_colorBack;
    float u_radius;
    float u_contrast;
    float u_size;
    float u_grainMixer;
    float u_grainOverlay;
    float u_grainSize;
    float u_grid;
    float u_originalColors;
    float u_inverted;
    float u_type;
  };

  static float hdValueNoise(float2 st) {
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

  static float hdLst(float edge0, float edge1, float x) {
    return clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
  }

  static float hdSst(float edge0, float edge1, float x) {
    return smoothstep(edge0, edge1, x);
  }

  static float hdGetCircle(float2 uv, float r, float baseR) {
    r = mix(.25 * baseR, 0., r);
    float d = length(uv - .5);
    float aa = fwidth(d);
    return 1. - smoothstep(r - aa, r + aa, d);
  }

  static float hdGetCell(float2 uv) {
    float insideX = step(0.0, uv.x) * (1.0 - step(1.0, uv.x));
    float insideY = step(0.0, uv.y) * (1.0 - step(1.0, uv.y));
    return insideX * insideY;
  }

  static float hdGetCircleWithHole(float2 uv, float r, float baseR) {
    float cell = hdGetCell(uv);
    r = mix(.75 * baseR, 0., r);
    float rMod = glsl_mod(r, .5);
    float d = length(uv - .5);
    float aa = fwidth(d);
    float circle = 1. - smoothstep(rMod - aa, rMod + aa, d);
    if (r < .5) {
      return circle;
    }
    return cell - circle;
  }

  static float hdGetGooeyBall(float2 uv, float r, float baseR, constant HalftoneDotsUniforms& u) {
    float d = length(uv - .5);
    float sizeRadius = .3;
    if (u.u_grid == 1.) {
      sizeRadius = .42;
    }
    sizeRadius = mix(sizeRadius * baseR, 0., r);
    d = 1. - hdSst(0., sizeRadius, d);
    d = pow(d, 2. + baseR);
    return d;
  }

  static float hdGetSoftBall(float2 uv, float r, float baseR) {
    float d = length(uv - .5);
    float sizeRadius = clamp(baseR, 0., 1.);
    sizeRadius = mix(.5 * sizeRadius, 0., r);
    d = 1. - hdLst(0., sizeRadius, d);
    float powRadius = 1. - hdLst(0., 2., baseR);
    d = pow(d, 4. + 3. * powRadius);
    return d;
  }

  static float hdGetUvFrame(float2 uv, float2 pad) {
    float aa = 0.0001;
    float left = smoothstep(-pad.x, -pad.x + aa, uv.x);
    float right = smoothstep(1.0 + pad.x, 1.0 + pad.x - aa, uv.x);
    float bottom = smoothstep(-pad.y, -pad.y + aa, uv.y);
    float top = smoothstep(1.0 + pad.y, 1.0 + pad.y - aa, uv.y);
    return left * right * bottom * top;
  }

  static float hdSigmoid(float x, float k) {
    return 1.0 / (1.0 + exp(-k * (x - 0.5)));
  }

  static float hdGetLumAtPx(float2 uv, float contrast, constant HalftoneDotsUniforms& u,
                            texture2d<float> imageTex, sampler imageSampler) {
    float4 tex = imageTex.sample(imageSampler, uv);
    float3 color = float3(
      hdSigmoid(tex.r, contrast),
      hdSigmoid(tex.g, contrast),
      hdSigmoid(tex.b, contrast)
    );
    float lum = dot(float3(0.2126, 0.7152, 0.0722), color);
    lum = mix(1., lum, tex.a);
    lum = (u.u_inverted > 0.5) ? (1. - lum) : lum;
    return lum;
  }

  static float hdGetLumBall(float2 p, float2 pad, float2 inCellOffset, float contrast,
                            float baseR, float stepSize, thread float4& ballColor,
                            constant HalftoneDotsUniforms& u,
                            texture2d<float> imageTex, sampler imageSampler) {
    p += inCellOffset;
    float2 uv_i = floor(p);
    float2 uv_f = fract(p);
    float2 samplingUV = (uv_i + .5 - inCellOffset) * pad + float2(.5);
    float outOfFrame = hdGetUvFrame(samplingUV, pad * stepSize);

    float lum = hdGetLumAtPx(samplingUV, contrast, u, imageTex, imageSampler);
    ballColor = imageTex.sample(imageSampler, samplingUV);
    ballColor.rgb *= ballColor.a;
    ballColor *= outOfFrame;

    float ball = 0.;
    if (u.u_type == 0.) {
      ball = hdGetCircle(uv_f, lum, baseR);
    } else if (u.u_type == 1.) {
      ball = hdGetGooeyBall(uv_f, lum, baseR, u);
    } else if (u.u_type == 2.) {
      ball = hdGetCircleWithHole(uv_f, lum, baseR);
    } else if (u.u_type == 3.) {
      ball = hdGetSoftBall(uv_f, lum, baseR);
    }

    return ball * outOfFrame;
  }

  fragment float4 ps_fragment(PSVertexOut in [[stage_in]],
                              constant PSGlobalUniforms& global [[buffer(0)]],
                              constant HalftoneDotsUniforms& u [[buffer(1)]],
                              constant PSSizingUniforms& sizing [[buffer(2)]],
                              texture2d<float> imageTex [[texture(1)]],
                              sampler imageSampler [[sampler(1)]]) {
    (void)global;
    float stepMultiplier = 1.;
    if (u.u_type == 0.) {
      stepMultiplier = 2.;
    } else if (u.u_type == 1. || u.u_type == 3.) {
      stepMultiplier = 6.;
    }

    float cellsPerSide = mix(300., 7., pow(u.u_size, .7));
    cellsPerSide /= stepMultiplier;
    float cellSizeY = 1. / cellsPerSide;
    float2 pad = cellSizeY * float2(1. / sizing.u_imageAspectRatio, 1.);
    if (u.u_type == 1. && u.u_grid == 1.) {
      pad *= .7;
    }

    float2 uv = in.imageUV;
    uv -= float2(.5);
    uv /= pad;

    float contrast = mix(0., 15., pow(u.u_contrast, 1.5));
    float baseRadius = u.u_radius;
    if (u.u_originalColors > 0.5) {
      contrast = mix(.1, 4., pow(u.u_contrast, 2.));
      baseRadius = 2. * pow(.5 * u.u_radius, .3);
    }

    float totalShape = 0.;
    float3 totalColor = float3(0.);
    float totalOpacity = 0.;

    float4 ballColor;
    float shape;
    float stepSize = 1. / stepMultiplier;
    for (float x = -0.5; x < 0.5; x += stepSize) {
      for (float y = -0.5; y < 0.5; y += stepSize) {
        float2 offset = float2(x, y);

        if (u.u_grid == 1.) {
          float rowIndex = floor((y + .5) / stepSize);
          float colIndex = floor((x + .5) / stepSize);
          if (stepSize == 1.) {
            rowIndex = floor(uv.y + y + 1.);
            if (u.u_type == 1.) {
              colIndex = floor(uv.x + x + 1.);
            }
          }
          if (u.u_type == 1.) {
            if (glsl_mod(rowIndex + colIndex, 2.) == 1.) {
              continue;
            }
          } else {
            if (glsl_mod(rowIndex, 2.) == 1.) {
              offset.x += .5 * stepSize;
            }
          }
        }

        shape = hdGetLumBall(uv, pad, offset, contrast, baseRadius, stepSize, ballColor, u, imageTex, imageSampler);
        totalColor += ballColor.rgb * shape;
        totalShape += shape;
        totalOpacity += shape;
      }
    }

    const float eps = 1e-4;
    totalColor /= max(totalShape, eps);
    totalOpacity /= max(totalShape, eps);

    float finalShape = 0.;
    if (u.u_type == 0.) {
      finalShape = min(1., totalShape);
    } else if (u.u_type == 1.) {
      float aa = fwidth(totalShape);
      float th = .5;
      finalShape = smoothstep(th - aa, th + aa, totalShape);
    } else if (u.u_type == 2.) {
      finalShape = min(1., totalShape);
    } else if (u.u_type == 3.) {
      finalShape = totalShape;
    }

    float2 grainSize = mix(2000., 200., u.u_grainSize) * float2(1., 1. / sizing.u_imageAspectRatio);
    float2 grainUV = in.imageUV - .5;
    grainUV *= grainSize;
    grainUV += .5;
    float grain = hdValueNoise(grainUV);
    grain = smoothstep(.55, .7 + .2 * u.u_grainMixer, grain);
    grain *= u.u_grainMixer;
    finalShape = mix(finalShape, 0., grain);

    float3 color = float3(0.);
    float opacity = 0.;

    if (u.u_originalColors > 0.5) {
      color = totalColor * finalShape;
      opacity = totalOpacity * finalShape;
      float3 bgColor = u.u_colorBack.rgb * u.u_colorBack.a;
      color = color + bgColor * (1. - opacity);
      opacity = opacity + u.u_colorBack.a * (1. - opacity);
    } else {
      float3 fgColor = u.u_colorFront.rgb * u.u_colorFront.a;
      float fgOpacity = u.u_colorFront.a;
      float3 bgColor = u.u_colorBack.rgb * u.u_colorBack.a;
      float bgOpacity = u.u_colorBack.a;

      color = fgColor * finalShape;
      opacity = fgOpacity * finalShape;
      color += bgColor * (1. - opacity);
      opacity += bgOpacity * (1. - opacity);
    }

    float grainOverlay = hdValueNoise(rotate(grainUV, 1.) + float2(3.));
    grainOverlay = mix(grainOverlay, hdValueNoise(rotate(grainUV, 2.) + float2(-1.)), .5);
    grainOverlay = pow(grainOverlay, 1.3);

    float grainOverlayV = grainOverlay * 2. - 1.;
    float3 grainOverlayColor = float3(step(0., grainOverlayV));
    float grainOverlayStrength = u.u_grainOverlay * abs(grainOverlayV);
    grainOverlayStrength = pow(grainOverlayStrength, .8);
    color = mix(color, grainOverlayColor, .5 * grainOverlayStrength);

    opacity += .5 * grainOverlayStrength;
    opacity = clamp(opacity, 0., 1.);

    return float4(color, opacity);
  }

  """
}
