import simd

/// Port of upstream `image-dithering.frag`.
public enum ImageDithering {
  /// Descriptor.
  public static let descriptor = ShaderDescriptor(
    name: "image-dithering",
    fragmentSource: source,
    usesImageTexture: true
  )

  /// Options for dither type.
  public enum DitherType: String, Sendable {
    case random
    case bayer2x2 = "2x2"
    case bayer4x4 = "4x4"
    case bayer8x8 = "8x8"

    /// Value passed to the `u_type` uniform (upstream `DitheringTypes`).
    public var uniformValue: Float {
      switch self {
      case .random: return 1
      case .bayer2x2: return 2
      case .bayer4x4: return 3
      case .bayer8x8: return 4
      }
    }
  }

  /// Parameters used to render this shader.
  public struct Params {
    /// Color front.
    public var colorFront: String
    /// Color back.
    public var colorBack: String
    /// Color highlight.
    public var colorHighlight: String
    /// Type.
    public var type: DitherType
    /// Size.
    public var size: Float
    /// Original colors.
    public var originalColors: Bool
    /// Inverted.
    public var inverted: Bool
    /// Color steps.
    public var colorSteps: Float
    /// Sizing.
    public var sizing: ShaderSizingParams
    /// Speed.
    public var speed: Double
    /// Frame.
    public var frame: Double

    /// Creates an instance.
    public init(
      colorFront: String = "#94ffaf",
      colorBack: String = "#000c38",
      colorHighlight: String = "#eaff94",
      type: DitherType = .bayer8x8,
      size: Float = 2,
      originalColors: Bool = false,
      inverted: Bool = false,
      colorSteps: Float = 2,
      sizing: ShaderSizingParams = ShaderSizingParams(fit: .cover, scale: 1),
      speed: Double = 0,
      frame: Double = 0
    ) {
      self.colorFront = colorFront
      self.colorBack = colorBack
      self.colorHighlight = colorHighlight
      self.type = type
      self.size = size
      self.originalColors = originalColors
      self.inverted = inverted
      self.colorSteps = colorSteps
      self.sizing = sizing
      self.speed = speed
      self.frame = frame
    }

    /// Matches `ImageDitheringUniforms` member order in the MSL source.
    public var uniforms: [UniformValue] {
      [
        .float4(ShaderColor.parse(colorFront)),
        .float4(ShaderColor.parse(colorBack)),
        .float4(ShaderColor.parse(colorHighlight)),
        .float(type.uniformValue),
        .float(size),
        .float(originalColors ? 1 : 0),
        .float(inverted ? 1 : 0),
        .float(colorSteps),
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
      name: "Noise",
      params: Params(
        colorFront: "#a2997c",
        colorBack: "#000000",
        colorHighlight: "#ededed",
        type: .random,
        size: 1,
        colorSteps: 1
      )
    ),
    Preset(
      name: "Retro",
      params: Params(
        colorFront: "#eeeeee",
        colorBack: "#5452ff",
        colorHighlight: "#eeeeee",
        type: .bayer2x2,
        size: 3,
        originalColors: true,
        colorSteps: 1
      )
    ),
    Preset(
      name: "Natural",
      params: Params(
        colorFront: "#ffffff",
        colorBack: "#000000",
        colorHighlight: "#ffffff",
        type: .bayer8x8,
        size: 2,
        originalColors: true,
        colorSteps: 5
      )
    ),
  ]

  static let source = """

  struct ImageDitheringUniforms {
    float4 u_colorFront;
    float4 u_colorBack;
    float4 u_colorHighlight;
    float u_type;
    float u_pxSize;
    float u_originalColors;
    float u_inverted;
    float u_colorSteps;
  };

  static float idGetUvFrame(float2 uv, float2 pad) {
    float aa = 0.0001;

    float left = smoothstep(-pad.x, -pad.x + aa, uv.x);
    float right = smoothstep(1.0 + pad.x, 1.0 + pad.x - aa, uv.x);
    float bottom = smoothstep(-pad.y, -pad.y + aa, uv.y);
    float top = smoothstep(1.0 + pad.y, 1.0 + pad.y - aa, uv.y);

    return left * right * bottom * top;
  }

  static float2 idGetImageUV(float2 uv, constant PSGlobalUniforms& global, constant PSSizingUniforms& sizing) {
    float2 boxOrigin = float2(.5 - sizing.u_originX, sizing.u_originY - .5);
    float r = sizing.u_rotation * PI / 180.;
    float2x2 graphicRotation = float2x2(float2(cos(r), sin(r)), float2(-sin(r), cos(r)));
    float2 graphicOffset = float2(-sizing.u_offsetX, sizing.u_offsetY);

    float2 imageBoxSize;
    if (sizing.u_fit == 1.) {
      imageBoxSize.x = min(global.u_resolution.x / sizing.u_imageAspectRatio, global.u_resolution.y) * sizing.u_imageAspectRatio;
    } else if (sizing.u_fit == 2.) {
      imageBoxSize.x = max(global.u_resolution.x / sizing.u_imageAspectRatio, global.u_resolution.y) * sizing.u_imageAspectRatio;
    } else {
      imageBoxSize.x = min(10.0, 10.0 / sizing.u_imageAspectRatio * sizing.u_imageAspectRatio);
    }
    imageBoxSize.y = imageBoxSize.x / sizing.u_imageAspectRatio;
    float2 imageBoxScale = global.u_resolution / imageBoxSize;

    float2 imageUV = uv;
    imageUV *= imageBoxScale;
    imageUV += boxOrigin * (imageBoxScale - 1.);
    imageUV += graphicOffset;
    imageUV /= sizing.u_scale;
    imageUV.x *= sizing.u_imageAspectRatio;
    imageUV = graphicRotation * imageUV;
    imageUV.x /= sizing.u_imageAspectRatio;

    imageUV += .5;
    imageUV.y = 1. - imageUV.y;

    return imageUV;
  }

  constant int idBayer2x2[4] = {0, 2, 3, 1};
  constant int idBayer4x4[16] = {
  0, 8, 2, 10,
  12, 4, 14, 6,
  3, 11, 1, 9,
  15, 7, 13, 5
  };

  constant int idBayer8x8[64] = {
  0, 32, 8, 40, 2, 34, 10, 42,
  48, 16, 56, 24, 50, 18, 58, 26,
  12, 44, 4, 36, 14, 46, 6, 38,
  60, 28, 52, 20, 62, 30, 54, 22,
  3, 35, 11, 43, 1, 33, 9, 41,
  51, 19, 59, 27, 49, 17, 57, 25,
  15, 47, 7, 39, 13, 45, 5, 37,
  63, 31, 55, 23, 61, 29, 53, 21
  };

  static float idGetBayerValue(float2 uv, int size) {
    int2 pos = int2(fract(uv / float(size)) * float(size));
    int index = pos.y * size + pos.x;

    if (size == 2) {
      return float(idBayer2x2[index]) / 4.0;
    } else if (size == 4) {
      return float(idBayer4x4[index]) / 16.0;
    } else if (size == 8) {
      return float(idBayer8x8[index]) / 64.0;
    }
    return 0.0;
  }

  fragment float4 ps_fragment(PSVertexOut in [[stage_in]],
                              constant PSGlobalUniforms& global [[buffer(0)]],
                              constant ImageDitheringUniforms& u [[buffer(1)]],
                              constant PSSizingUniforms& sizing [[buffer(2)]],
                              texture2d<float> imageTex [[texture(1)]],
                              sampler imageSampler [[sampler(1)]]) {
    float2 fragCoordGL = float2(in.position.x, global.u_resolution.y - in.position.y);

    float pxSize = u.u_pxSize * global.u_pixelRatio;
    float2 pxSizeUV = fragCoordGL - .5 * global.u_resolution;
    pxSizeUV /= pxSize;
    float2 canvasPixelizedUV = (floor(pxSizeUV) + .5) * pxSize;
    float2 normalizedUV = canvasPixelizedUV / global.u_resolution;

    float2 imageUV = idGetImageUV(normalizedUV, global, sizing);
    float2 ditheringNoiseUV = canvasPixelizedUV;
    float4 image = imageTex.sample(imageSampler, imageUV);
    float frame = idGetUvFrame(imageUV, pxSize / global.u_resolution);

    int type = int(floor(u.u_type));
    float dithering = 0.0;

    float lum = dot(float3(.2126, .7152, .0722), image.rgb);
    lum = (u.u_inverted > 0.5) ? (1. - lum) : lum;

    switch (type) {
    case 1:
      dithering = step(hash21(ditheringNoiseUV), lum);
      break;
    case 2:
      dithering = idGetBayerValue(pxSizeUV, 2);
      break;
    case 3:
      dithering = idGetBayerValue(pxSizeUV, 4);
      break;
    default:
      dithering = idGetBayerValue(pxSizeUV, 8);
      break;
    }

    float colorSteps = max(floor(u.u_colorSteps), 1.);
    float3 color = float3(0.0);
    float opacity = 1.;

    dithering -= .5;
    float brightness = clamp(lum + dithering / colorSteps, 0.0, 1.0);
    brightness = mix(0.0, brightness, frame);
    brightness = mix(0.0, brightness, image.a);
    float quantLum = floor(brightness * colorSteps + 0.5) / colorSteps;
    quantLum = mix(0.0, quantLum, frame);

    if (u.u_originalColors > 0.5) {
      float3 normColor = image.rgb / max(lum, 0.001);
      color = normColor * quantLum;

      float quantAlpha = floor(image.a * colorSteps + 0.5) / colorSteps;
      opacity = mix(quantLum, 1., quantAlpha);
    } else {
      float3 fgColor = u.u_colorFront.rgb * u.u_colorFront.a;
      float fgOpacity = u.u_colorFront.a;
      float3 bgColor = u.u_colorBack.rgb * u.u_colorBack.a;
      float bgOpacity = u.u_colorBack.a;
      float3 hlColor = u.u_colorHighlight.rgb * u.u_colorHighlight.a;
      float hlOpacity = u.u_colorHighlight.a;

      fgColor = mix(fgColor, hlColor, step(1.02 - .02 * u.u_colorSteps, brightness));
      fgOpacity = mix(fgOpacity, hlOpacity, step(1.02 - .02 * u.u_colorSteps, brightness));

      color = fgColor * quantLum;
      opacity = fgOpacity * quantLum;
      color += bgColor * (1.0 - opacity);
      opacity += bgOpacity * (1.0 - opacity);
    }

    return float4(color, opacity);
  }
  """
}
