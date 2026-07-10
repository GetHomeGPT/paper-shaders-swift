import simd

/// Port of upstream `halftone-cmyk.frag`.
public enum HalftoneCmyk {
  /// Descriptor.
  public static let descriptor = ShaderDescriptor(
    name: "halftone-cmyk",
    fragmentSource: source,
    maskFragmentFunctionName: "ps_mask_fragment",
    usesNoiseTexture: true,
    usesImageTexture: true,
    isAnimated: false
  )

  /// Options for halftone type.
  public enum HalftoneType: String, Sendable {
    case dots
    case ink
    case sharp

    var uniformValue: Float {
      switch self {
      case .dots: return 0
      case .ink: return 1
      case .sharp: return 2
      }
    }
  }

  /// Parameters used to render this shader.
  public struct Params {
    /// Color back.
    public var colorBack: String
    /// Color c.
    public var colorC: String
    /// Color m.
    public var colorM: String
    /// Color y.
    public var colorY: String
    /// Color k.
    public var colorK: String
    /// Size.
    public var size: Float
    /// Contrast.
    public var contrast: Float
    /// Grain size.
    public var grainSize: Float
    /// Grain mixer.
    public var grainMixer: Float
    /// Grain overlay.
    public var grainOverlay: Float
    /// Grid noise.
    public var gridNoise: Float
    /// Softness.
    public var softness: Float
    /// Flood c.
    public var floodC: Float
    /// Flood m.
    public var floodM: Float
    /// Flood y.
    public var floodY: Float
    /// Flood k.
    public var floodK: Float
    /// Gain c.
    public var gainC: Float
    /// Gain m.
    public var gainM: Float
    /// Gain y.
    public var gainY: Float
    /// Gain k.
    public var gainK: Float
    /// Type.
    public var type: HalftoneType
    /// Sizing.
    public var sizing: ShaderSizingParams
    /// Speed.
    public var speed: Double
    /// Frame.
    public var frame: Double

    /// Creates an instance.
    public init(
      colorBack: String = "#fbfaf5",
      colorC: String = "#00b4ff",
      colorM: String = "#fc519f",
      colorY: String = "#ffd800",
      colorK: String = "#231f20",
      size: Float = 0.2,
      contrast: Float = 1,
      grainSize: Float = 0.5,
      grainMixer: Float = 0,
      grainOverlay: Float = 0,
      gridNoise: Float = 0.2,
      softness: Float = 1,
      floodC: Float = 0.15,
      floodM: Float = 0,
      floodY: Float = 0,
      floodK: Float = 0,
      gainC: Float = 0.3,
      gainM: Float = 0,
      gainY: Float = 0.2,
      gainK: Float = 0,
      type: HalftoneType = .ink,
      sizing: ShaderSizingParams = ShaderSizingParams(fit: .cover),
      speed: Double = 0,
      frame: Double = 0
    ) {
      self.colorBack = colorBack
      self.colorC = colorC
      self.colorM = colorM
      self.colorY = colorY
      self.colorK = colorK
      self.size = size
      self.contrast = contrast
      self.grainSize = grainSize
      self.grainMixer = grainMixer
      self.grainOverlay = grainOverlay
      self.gridNoise = gridNoise
      self.softness = softness
      self.floodC = floodC
      self.floodM = floodM
      self.floodY = floodY
      self.floodK = floodK
      self.gainC = gainC
      self.gainM = gainM
      self.gainY = gainY
      self.gainK = gainK
      self.type = type
      self.sizing = sizing
      self.speed = speed
      self.frame = frame
    }

    /// Matches `HalftoneCmykUniforms` member order in the MSL source.
    /// Upstream declares `u_minDot`, but the fragment body never reads it.
    public var uniforms: [UniformValue] {
      [
        .float4(ShaderColor.parse(colorBack)),
        .float4(ShaderColor.parse(colorC)),
        .float4(ShaderColor.parse(colorM)),
        .float4(ShaderColor.parse(colorY)),
        .float4(ShaderColor.parse(colorK)),
        .float(size),
        .float(contrast),
        .float(grainSize),
        .float(grainMixer),
        .float(grainOverlay),
        .float(gridNoise),
        .float(softness),
        .float(floodC),
        .float(floodM),
        .float(floodY),
        .float(floodK),
        .float(gainC),
        .float(gainM),
        .float(gainY),
        .float(gainK),
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
      name: "Drops",
      params: Params(
        colorBack: "#eeefd7",
        colorC: "#00b2ff",
        colorM: "#fc4f4f",
        colorY: "#ffd900",
        colorK: "#231f20",
        size: 0.88,
        contrast: 1.15,
        grainSize: 0.01,
        grainMixer: 0.05,
        grainOverlay: 0.25,
        gridNoise: 0.5,
        softness: 0,
        floodC: 0.15,
        floodM: 0,
        floodY: 0,
        floodK: 0,
        gainC: 1,
        gainM: 0.44,
        gainY: -1,
        gainK: 0,
        type: .ink
      )
    ),
    Preset(
      name: "Newspaper",
      params: Params(
        colorBack: "#f2f1e8",
        colorC: "#7a7a75",
        colorM: "#7a7a75",
        colorY: "#7a7a75",
        colorK: "#231f20",
        size: 0.01,
        contrast: 2,
        grainSize: 0,
        grainMixer: 0,
        grainOverlay: 0.2,
        gridNoise: 0.6,
        softness: 0.2,
        floodC: 0,
        floodM: 0,
        floodY: 0,
        floodK: 0.1,
        gainC: -0.17,
        gainM: -0.45,
        gainY: -0.45,
        gainK: 0,
        type: .dots
      )
    ),
    Preset(
      name: "Vintage",
      params: Params(
        colorBack: "#fffaf0",
        colorC: "#59afc5",
        colorM: "#d8697c",
        colorY: "#fad85c",
        colorK: "#2d2824",
        size: 0.2,
        contrast: 1.25,
        grainSize: 0.5,
        grainMixer: 0.15,
        grainOverlay: 0.1,
        gridNoise: 0.45,
        softness: 0.4,
        floodC: 0.15,
        floodM: 0,
        floodY: 0,
        floodK: 0,
        gainC: 0.3,
        gainM: 0,
        gainY: 0.2,
        gainK: 0,
        type: .sharp
      )
    ),
  ]

  static let source = """

  struct HalftoneCmykUniforms {
    float4 u_colorBack;
    float4 u_colorC;
    float4 u_colorM;
    float4 u_colorY;
    float4 u_colorK;
    float u_size;
    float u_contrast;
    float u_grainSize;
    float u_grainMixer;
    float u_grainOverlay;
    float u_gridNoise;
    float u_softness;
    float u_floodC;
    float u_floodM;
    float u_floodY;
    float u_floodK;
    float u_gainC;
    float u_gainM;
    float u_gainY;
    float u_gainK;
    float u_type;
  };

  constant float hcShiftC = -.5;
  constant float hcShiftM = -.25;
  constant float hcShiftY = .2;
  constant float hcShiftK = 0.;
  constant float hcCosC = 0.9659258;
  constant float hcSinC = 0.2588190;
  constant float hcCosM = 0.2588190;
  constant float hcSinM = 0.9659258;
  constant float hcCosY = 1.0;
  constant float hcSinY = 0.0;
  constant float hcCosK = 0.7071068;
  constant float hcSinK = 0.7071068;

  static float2 hcRandomRG(float2 p, texture2d<float> noiseTex, sampler noiseSampler) {
    float2 uv = floor(p) / 100. + .5;
    return noiseTex.sample(noiseSampler, fract(uv), level(0)).rg;
  }

  static float hcQuadFwidth(float v) {
    return abs(quad_shuffle_xor(v, 1) - v) + abs(quad_shuffle_xor(v, 2) - v);
  }

  static float3 hcHash23(float2 p) {
    float3 p3 = fract(float3(p.x, p.y, p.x) * float3(0.3183099, 0.3678794, 0.3141592)) + 0.1;
    p3 += dot(p3, p3.yzx + 19.19);
    return fract(float3(p3.x * p3.y, p3.y * p3.z, p3.z * p3.x));
  }

  static float hcSst(float edge0, float edge1, float x) {
    return smoothstep(edge0, edge1, x);
  }

  static float3 hcValueNoise3(float2 st) {
    float2 i = floor(st);
    float2 f = fract(st);
    float3 a = hcHash23(i);
    float3 b = hcHash23(i + float2(1.0, 0.0));
    float3 c = hcHash23(i + float2(0.0, 1.0));
    float3 d = hcHash23(i + float2(1.0, 1.0));
    float2 u = f * f * (3.0 - 2.0 * f);
    float3 x1 = mix(a, b, u.x);
    float3 x2 = mix(c, d, u.x);
    return mix(x1, x2, u.y);
  }

  static float hcGetUvFrame(float2 uv, float2 pad) {
    float left = smoothstep(-pad.x, 0., uv.x);
    float right = smoothstep(1. + pad.x, 1., uv.x);
    float bottom = smoothstep(-pad.y, 0., uv.y);
    float top = smoothstep(1. + pad.y, 1., uv.y);
    return left * right * bottom * top;
  }

  static float4 hcRGBAtoCMYK(float4 rgba) {
    float k = 1. - max(max(rgba.r, rgba.g), rgba.b);
    float denom = 1. - k;
    float3 cmy = float3(0.);
    if (denom > 1e-5) {
      cmy = (1. - rgba.rgb - float3(k)) / denom;
    }
    return float4(cmy, k) * rgba.a;
  }

  static float3 hcApplyContrast(float3 rgb, constant HalftoneCmykUniforms& u) {
    return clamp((rgb - 0.5) * u.u_contrast + 0.5, 0.0, 1.0);
  }

  static float hcGetCyan(float4 rgba, constant HalftoneCmykUniforms& u) {
    float3 c = hcApplyContrast(rgba.rgb, u);
    float maxRGB = max(max(c.r, c.g), c.b);
    return (maxRGB > 1e-5 ? (maxRGB - c.r) / maxRGB : 0.) * rgba.a;
  }

  static float hcGetMagenta(float4 rgba, constant HalftoneCmykUniforms& u) {
    float3 c = hcApplyContrast(rgba.rgb, u);
    float maxRGB = max(max(c.r, c.g), c.b);
    return (maxRGB > 1e-5 ? (maxRGB - c.g) / maxRGB : 0.) * rgba.a;
  }

  static float hcGetYellow(float4 rgba, constant HalftoneCmykUniforms& u) {
    float3 c = hcApplyContrast(rgba.rgb, u);
    float maxRGB = max(max(c.r, c.g), c.b);
    return (maxRGB > 1e-5 ? (maxRGB - c.b) / maxRGB : 0.) * rgba.a;
  }

  static float hcGetBlack(float4 rgba, constant HalftoneCmykUniforms& u) {
    float3 c = hcApplyContrast(rgba.rgb, u);
    return (1. - max(max(c.r, c.g), c.b)) * rgba.a;
  }

  static float2 hcCellCenterPos(float2 uv, float2 cellOffset, float channelIdx,
                                constant HalftoneCmykUniforms& u,
                                texture2d<float> noiseTex, sampler noiseSampler) {
    float2 cellCenter = floor(uv) + .5 + cellOffset;
    return cellCenter + (hcRandomRG(cellCenter + channelIdx * 50., noiseTex, noiseSampler) - .5) * u.u_gridNoise;
  }

  static float2 hcGridToImageUV(float2 cellCenter, float cosA, float sinA, float shift, float2 pad) {
    float2 uvGrid = float2x2(float2(cosA, -sinA), float2(sinA, cosA)) * (cellCenter - float2(shift));
    return uvGrid * pad + 0.5;
  }

  static float hcColorMask(float2 pos, float2 cellCenter, float rad, float transparency,
                           float grain, float channelAddon, float channelGain,
                           float generalComp, bool isJoined, constant HalftoneCmykUniforms& u) {
    float dist = length(pos - cellCenter);
    float radius = rad;
    radius *= (1. + generalComp);
    radius += (.15 + channelGain * radius);
    radius = max(0., radius);
    radius = mix(0., radius, transparency);
    radius += channelAddon;
    radius *= (1. - grain);

    float mask = 1. - hcSst(0., radius, dist);
    if (isJoined) {
      mask = pow(mask, 1.2);
    } else {
      mask = hcSst(.5 - .5 * u.u_softness, .51 + .49 * u.u_softness, mask);
    }
    mask *= mix(1., mix(.5, 1., 1.5 * radius), u.u_softness);
    return mask;
  }

  static float4 hcOutMaskForUV(float2 uv, float imageAspectRatio,
                               constant HalftoneCmykUniforms& u,
                               texture2d<float> noiseTex,
                               sampler noiseSampler,
                               texture2d<float> imageTex,
                               sampler imageSampler) {
    float cellsPerSide = mix(400.0, 7.0, pow(u.u_size, 0.7));
    float cellSizeY = 1.0 / cellsPerSide;
    float2 pad = cellSizeY * float2(1.0 / imageAspectRatio, 1.0);
    float2 uvGrid = (uv - .5) / pad;
    float insideImageBox = hcGetUvFrame(uv, pad);

    float generalComp = .1 * u.u_softness + .1 * u.u_gridNoise + .1 * (1. - step(0.5, u.u_type)) * (1.5 - u.u_softness);

    float2 uvC = float2x2(float2(hcCosC, hcSinC), float2(-hcSinC, hcCosC)) * uvGrid + hcShiftC;
    float2 uvM = float2x2(float2(hcCosM, hcSinM), float2(-hcSinM, hcCosM)) * uvGrid + hcShiftM;
    float2 uvY = float2x2(float2(hcCosY, hcSinY), float2(-hcSinY, hcCosY)) * uvGrid + hcShiftY;
    float2 uvK = float2x2(float2(hcCosK, hcSinK), float2(-hcSinK, hcCosK)) * uvGrid + hcShiftK;

    float2 grainSize = mix(2000., 200., u.u_grainSize) * float2(1., 1. / imageAspectRatio);
    float2 grainUV = (uv - .5) * grainSize + .5;
    float3 noiseValues = hcValueNoise3(grainUV);
    float grain = hcSst(.55, 1., noiseValues.r);
    grain *= u.u_grainMixer;

    float4 outMask = float4(0.);
    bool isJoined = u.u_type > 0.5;

    if (u.u_type < 1.5) {
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          float2 cellOffset = float2(float(dx), float(dy));

          float2 cellCenterC = hcCellCenterPos(uvC, cellOffset, 0., u, noiseTex, noiseSampler);
          float4 texC = imageTex.sample(imageSampler, hcGridToImageUV(cellCenterC, hcCosC, hcSinC, hcShiftC, pad), level(0));
          outMask.x += hcColorMask(uvC, cellCenterC, hcGetCyan(texC, u), insideImageBox * texC.a, grain, u.u_floodC, u.u_gainC, generalComp, isJoined, u);

          float2 cellCenterM = hcCellCenterPos(uvM, cellOffset, 1., u, noiseTex, noiseSampler);
          float4 texM = imageTex.sample(imageSampler, hcGridToImageUV(cellCenterM, hcCosM, hcSinM, hcShiftM, pad), level(0));
          outMask.y += hcColorMask(uvM, cellCenterM, hcGetMagenta(texM, u), insideImageBox * texM.a, grain, u.u_floodM, u.u_gainM, generalComp, isJoined, u);

          float2 cellCenterY = hcCellCenterPos(uvY, cellOffset, 2., u, noiseTex, noiseSampler);
          float4 texY = imageTex.sample(imageSampler, hcGridToImageUV(cellCenterY, hcCosY, hcSinY, hcShiftY, pad), level(0));
          outMask.z += hcColorMask(uvY, cellCenterY, hcGetYellow(texY, u), insideImageBox * texY.a, grain, u.u_floodY, u.u_gainY, generalComp, isJoined, u);

          float2 cellCenterK = hcCellCenterPos(uvK, cellOffset, 3., u, noiseTex, noiseSampler);
          float4 texK = imageTex.sample(imageSampler, hcGridToImageUV(cellCenterK, hcCosK, hcSinK, hcShiftK, pad), level(0));
          outMask.w += hcColorMask(uvK, cellCenterK, hcGetBlack(texK, u), insideImageBox * texK.a, grain, u.u_floodK, u.u_gainK, generalComp, isJoined, u);
        }
      }
    } else {
      float4 tex = imageTex.sample(imageSampler, uv, level(0));
      tex.rgb = hcApplyContrast(tex.rgb, u);
      insideImageBox *= tex.a;
      float4 cmykOriginal = hcRGBAtoCMYK(tex);
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          float2 cellOffset = float2(float(dx), float(dy));

          outMask.x += hcColorMask(uvC, hcCellCenterPos(uvC, cellOffset, 0., u, noiseTex, noiseSampler), cmykOriginal.x, insideImageBox, grain, u.u_floodC, u.u_gainC, generalComp, isJoined, u);
          outMask.y += hcColorMask(uvM, hcCellCenterPos(uvM, cellOffset, 1., u, noiseTex, noiseSampler), cmykOriginal.y, insideImageBox, grain, u.u_floodM, u.u_gainM, generalComp, isJoined, u);
          outMask.z += hcColorMask(uvY, hcCellCenterPos(uvY, cellOffset, 2., u, noiseTex, noiseSampler), cmykOriginal.z, insideImageBox, grain, u.u_floodY, u.u_gainY, generalComp, isJoined, u);
          outMask.w += hcColorMask(uvK, hcCellCenterPos(uvK, cellOffset, 3., u, noiseTex, noiseSampler), cmykOriginal.w, insideImageBox, grain, u.u_floodK, u.u_gainK, generalComp, isJoined, u);
        }
      }
    }

    return outMask;
  }

  static float3 hcApplyInk(float3 paper, float3 inkColor, float cov) {
    float3 inkEffect = mix(float3(1.0), inkColor, clamp(cov, 0.0, 1.0));
    return paper * inkEffect;
  }

  fragment float4 ps_mask_fragment(PSVertexOut in [[stage_in]],
                                   constant PSGlobalUniforms& global [[buffer(0)]],
                                   constant HalftoneCmykUniforms& u [[buffer(1)]],
                                   constant PSSizingUniforms& sizing [[buffer(2)]],
                                   texture2d<float> noiseTex [[texture(0)]],
                                   sampler noiseSampler [[sampler(0)]],
                                   texture2d<float> imageTex [[texture(1)]],
                                   sampler imageSampler [[sampler(1)]]) {
    (void)global;
    return clamp(hcOutMaskForUV(in.imageUV, sizing.u_imageAspectRatio, u, noiseTex, noiseSampler, imageTex, imageSampler), 0., 1.);
  }

  fragment float4 ps_fragment(PSVertexOut in [[stage_in]],
                              constant PSGlobalUniforms& global [[buffer(0)]],
                              constant HalftoneCmykUniforms& u [[buffer(1)]],
                              constant PSSizingUniforms& sizing [[buffer(2)]],
                              texture2d<float> noiseTex [[texture(0)]],
                              sampler noiseSampler [[sampler(0)]],
                              texture2d<float> imageTex [[texture(1)]],
                              sampler imageSampler [[sampler(1)]],
                              texture2d<float> maskTex [[texture(2)]]) {
    float2 uv = in.imageUV;

    float2 grainSize = mix(2000., 200., u.u_grainSize) * float2(1., 1. / sizing.u_imageAspectRatio);
    float2 grainUV = (in.imageUV - .5) * grainSize + .5;
    float3 noiseValues = hcValueNoise3(grainUV);
    uint2 maxCoord = uint2(maskTex.get_width() - 1, maskTex.get_height() - 1);
    uint2 pixel = min(uint2(in.position.xy), maxCoord);
    float4 outMask = maskTex.read(pixel);
    float4 outMaskDx = maskTex.read(uint2(min(pixel.x ^ 1, maxCoord.x), pixel.y));
    float4 outMaskDy = maskTex.read(uint2(pixel.x, min(pixel.y ^ 1, maxCoord.y)));
    float4 maskAA = abs(outMaskDx - outMask) + abs(outMaskDy - outMask);
    bool isJoined = u.u_type > 0.5;

    float C = outMask.x;
    float M = outMask.y;
    float Y = outMask.z;
    float K = outMask.w;

    if (isJoined) {
      float th = .5;
      float sLeft = th * u.u_softness;
      float sRight = (1. - th) * u.u_softness + .01;
      C = smoothstep(th - sLeft - maskAA.x, th + sRight, C);
      M = smoothstep(th - sLeft - maskAA.y, th + sRight, M);
      Y = smoothstep(th - sLeft - maskAA.z, th + sRight, Y);
      K = smoothstep(th - sLeft - maskAA.w, th + sRight, K);
    }

    C *= u.u_colorC.a;
    M *= u.u_colorM.a;
    Y *= u.u_colorY.a;
    K *= u.u_colorK.a;

    float3 ink = float3(1.);
    ink = hcApplyInk(ink, u.u_colorK.rgb, K);
    ink = hcApplyInk(ink, u.u_colorC.rgb, C);
    ink = hcApplyInk(ink, u.u_colorM.rgb, M);
    ink = hcApplyInk(ink, u.u_colorY.rgb, Y);

    float shape = clamp(max(max(C, M), max(Y, K)), 0., 1.);

    float3 color = u.u_colorBack.rgb * u.u_colorBack.a;
    float opacity = u.u_colorBack.a;
    color = mix(color, ink, shape);
    opacity += shape;
    opacity = clamp(opacity, 0., 1.);

    float grainOverlay = mix(noiseValues.g, noiseValues.b, .5);
    grainOverlay = pow(grainOverlay, 1.3);

    float grainOverlayV = grainOverlay * 2. - 1.;
    float3 grainOverlayColor = float3(step(0., grainOverlayV));
    float grainOverlayStrength = u.u_grainOverlay * abs(grainOverlayV);
    grainOverlayStrength = pow(grainOverlayStrength, .8);
    color = mix(color, grainOverlayColor, .5 * grainOverlayStrength);

    opacity += .5 * grainOverlayStrength;
    opacity = clamp(opacity, 0., 1.);

    (void)global;
    return float4(color, opacity);
  }

  """
}
