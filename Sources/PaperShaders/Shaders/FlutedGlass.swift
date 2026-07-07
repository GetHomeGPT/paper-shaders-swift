import simd

/// Port of upstream `fluted-glass.frag`.
public enum FlutedGlass {
  /// Descriptor.
  public static let descriptor = ShaderDescriptor(
    name: "fluted-glass",
    fragmentSource: source,
    usesImageTexture: true,
    usesImageMipmaps: true
  )

  /// Options for shape.
  public enum Shape: String, Sendable {
    case lines
    case linesIrregular
    case wave
    case zigzag
    case pattern

    var uniformValue: Float {
      switch self {
      case .lines: return 1
      case .linesIrregular: return 2
      case .wave: return 3
      case .zigzag: return 4
      case .pattern: return 5
      }
    }
  }

  /// Options for distortion shape.
  public enum DistortionShape: String, Sendable {
    case prism
    case lens
    case contour
    case cascade
    case flat

    var uniformValue: Float {
      switch self {
      case .prism: return 1
      case .lens: return 2
      case .contour: return 3
      case .cascade: return 4
      case .flat: return 5
      }
    }
  }

  /// Parameters used to render this shader.
  public struct Params {
    /// Color back.
    public var colorBack: String
    /// Color shadow.
    public var colorShadow: String
    /// Color highlight.
    public var colorHighlight: String
    /// Size.
    public var size: Float
    /// Shadows.
    public var shadows: Float
    /// Angle.
    public var angle: Float
    /// Stretch.
    public var stretch: Float
    /// Shape.
    public var shape: Shape
    /// Distortion.
    public var distortion: Float
    /// Highlights.
    public var highlights: Float
    /// Distortion shape.
    public var distortionShape: DistortionShape
    /// Shift.
    public var shift: Float
    /// Blur.
    public var blur: Float
    /// Edges.
    public var edges: Float
    /// Margin left.
    public var marginLeft: Float
    /// Margin right.
    public var marginRight: Float
    /// Margin top.
    public var marginTop: Float
    /// Margin bottom.
    public var marginBottom: Float
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
      colorBack: String = "#00000000",
      colorShadow: String = "#000000",
      colorHighlight: String = "#ffffff",
      size: Float = 0.5,
      shadows: Float = 0.25,
      angle: Float = 0,
      stretch: Float = 0,
      shape: Shape = .lines,
      distortion: Float = 0.5,
      highlights: Float = 0.1,
      distortionShape: DistortionShape = .prism,
      shift: Float = 0,
      blur: Float = 0,
      edges: Float = 0.25,
      marginLeft: Float = 0,
      marginRight: Float = 0,
      marginTop: Float = 0,
      marginBottom: Float = 0,
      grainMixer: Float = 0,
      grainOverlay: Float = 0,
      sizing: ShaderSizingParams = ShaderSizingParams(fit: .cover),
      speed: Double = 0,
      frame: Double = 0
    ) {
      self.colorBack = colorBack
      self.colorShadow = colorShadow
      self.colorHighlight = colorHighlight
      self.size = size
      self.shadows = shadows
      self.angle = angle
      self.stretch = stretch
      self.shape = shape
      self.distortion = distortion
      self.highlights = highlights
      self.distortionShape = distortionShape
      self.shift = shift
      self.blur = blur
      self.edges = edges
      self.marginLeft = marginLeft
      self.marginRight = marginRight
      self.marginTop = marginTop
      self.marginBottom = marginBottom
      self.grainMixer = grainMixer
      self.grainOverlay = grainOverlay
      self.sizing = sizing
      self.speed = speed
      self.frame = frame
    }

    /// Matches `FlutedGlassUniforms` member order in the MSL source.
    public var uniforms: [UniformValue] {
      [
        .float4(ShaderColor.parse(colorBack)),
        .float4(ShaderColor.parse(colorShadow)),
        .float4(ShaderColor.parse(colorHighlight)),
        .float(size),
        .float(shadows),
        .float(angle),
        .float(stretch),
        .float(shape.uniformValue),
        .float(distortion),
        .float(highlights),
        .float(distortionShape.uniformValue),
        .float(shift),
        .float(blur),
        .float(edges),
        .float(marginLeft),
        .float(marginRight),
        .float(marginTop),
        .float(marginBottom),
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
      name: "Abstract",
      params: Params(
        size: 0.7,
        shadows: 0,
        angle: 30,
        stretch: 1,
        shape: .linesIrregular,
        distortion: 1,
        highlights: 0,
        distortionShape: .flat,
        blur: 1,
        edges: 0.5,
        grainMixer: 0.1,
        grainOverlay: 0.1,
        sizing: ShaderSizingParams(fit: .cover, scale: 4)
      )
    ),
    Preset(
      name: "Waves",
      params: Params(
        size: 0.9,
        shadows: 0,
        stretch: 1,
        shape: .wave,
        highlights: 0,
        distortionShape: .contour,
        blur: 0.1,
        edges: 0.5,
        grainOverlay: 0.05,
        sizing: ShaderSizingParams(fit: .cover, scale: 1.2)
      )
    ),
    Preset(
      name: "Folds",
      params: Params(
        size: 0.4,
        shadows: 0.4,
        distortion: 0.75,
        highlights: 0,
        distortionShape: .cascade,
        blur: 0.25,
        edges: 0.5,
        marginLeft: 0.1,
        marginRight: 0.1,
        marginTop: 0.1,
        marginBottom: 0.1
      )
    ),
  ]

  static let source = """

  struct FlutedGlassUniforms {
    float4 u_colorBack;
    float4 u_colorShadow;
    float4 u_colorHighlight;
    float u_size;
    float u_shadows;
    float u_angle;
    float u_stretch;
    float u_shape;
    float u_distortion;
    float u_highlights;
    float u_distortionShape;
    float u_shift;
    float u_blur;
    float u_edges;
    float u_marginLeft;
    float u_marginRight;
    float u_marginTop;
    float u_marginBottom;
    float u_grainMixer;
    float u_grainOverlay;
  };

  constant int FG_MAX_RADIUS = 50;

  static float fgValueNoise(float2 st) {
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

  static float fgGetUvFrame(float2 uv, float softness) {
    float aax = 2. * fwidth(uv.x);
    float aay = 2. * fwidth(uv.y);
    float left = smoothstep(0., aax + softness, uv.x);
    float right = 1. - smoothstep(1. - softness - aax, 1., uv.x);
    float bottom = smoothstep(0., aay + softness, uv.y);
    float top = 1. - smoothstep(1. - softness - aay, 1., uv.y);
    return left * right * bottom * top;
  }

  static float4 fgSamplePremultiplied(texture2d<float> imageTex, sampler imageSampler, float2 uv) {
    float4 c = imageTex.sample(imageSampler, uv);
    c.rgb *= c.a;
    return c;
  }

  static float4 fgGetBlur(texture2d<float> imageTex, sampler imageSampler, float2 uv, float2 texelSize, float2 dir, float sigma) {
    if (sigma <= .5) {
      return imageTex.sample(imageSampler, uv);
    }
    int radius = int(min(float(FG_MAX_RADIUS), ceil(3.0 * sigma)));

    float twoSigma2 = 2.0 * sigma * sigma;
    float gaussianNorm = 1.0 / sqrt(TWO_PI * sigma * sigma);

    float4 sum = fgSamplePremultiplied(imageTex, imageSampler, uv) * gaussianNorm;
    float weightSum = gaussianNorm;

    for (int i = 1; i <= FG_MAX_RADIUS; i++) {
      if (i > radius) {
        break;
      }

      float x = float(i);
      float w = exp(-(x * x) / twoSigma2) * gaussianNorm;

      float2 offset = dir * texelSize * x;
      float4 s1 = fgSamplePremultiplied(imageTex, imageSampler, uv + offset);
      float4 s2 = fgSamplePremultiplied(imageTex, imageSampler, uv - offset);

      sum += (s1 + s2) * w;
      weightSum += 2.0 * w;
    }

    float4 result = sum / weightSum;
    if (result.a > 0.) {
      result.rgb /= result.a;
    }

    return result;
  }

  static float2 fgRotateAspect(float2 p, float a, float aspect) {
    p.x *= aspect;
    p = rotate(p, a);
    p.x /= aspect;
    return p;
  }

  static float fgSmoothFract(float x) {
    float f = fract(x);
    float w = fwidth(x);

    float edge = abs(f - 0.5) - 0.5;
    float band = smoothstep(-w, w, edge);

    return mix(f, 1.0 - f, band);
  }

  fragment float4 ps_fragment(PSVertexOut in [[stage_in]],
                              constant PSGlobalUniforms& global [[buffer(0)]],
                              constant FlutedGlassUniforms& u [[buffer(1)]],
                              constant PSSizingUniforms& sizing [[buffer(2)]],
                              texture2d<float> imageTex [[texture(1)]],
                              sampler imageSampler [[sampler(1)]]) {
    float patternRotation = -u.u_angle * PI / 180.;
    float patternSize = mix(200., 5., u.u_size);

    float2 uv = in.imageUV;

    float2 fragCoordGL = float2(in.position.x, global.u_resolution.y - in.position.y);
    float2 uvMask = fragCoordGL / global.u_resolution;
    float2 sw = float2(.005);
    float4 margins = float4(u.u_marginLeft, u.u_marginTop, u.u_marginRight, u.u_marginBottom);
    float mask =
    smoothstep(margins[0], margins[0] + sw.x, uvMask.x + sw.x) *
    smoothstep(margins[2], margins[2] + sw.x, 1.0 - uvMask.x + sw.x) *
    smoothstep(margins[1], margins[1] + sw.y, uvMask.y + sw.y) *
    smoothstep(margins[3], margins[3] + sw.y, 1.0 - uvMask.y + sw.y);
    float maskOuter =
    smoothstep(margins[0] - sw.x, margins[0], uvMask.x + sw.x) *
    smoothstep(margins[2] - sw.x, margins[2], 1.0 - uvMask.x + sw.x) *
    smoothstep(margins[1] - sw.y, margins[1], uvMask.y + sw.y) *
    smoothstep(margins[3] - sw.y, margins[3], 1.0 - uvMask.y + sw.y);
    float maskStroke = maskOuter - mask;
    float maskInner =
    smoothstep(margins[0] - 2. * sw.x, margins[0], uvMask.x) *
    smoothstep(margins[2] - 2. * sw.x, margins[2], 1.0 - uvMask.x) *
    smoothstep(margins[1] - 2. * sw.y, margins[1], uvMask.y) *
    smoothstep(margins[3] - 2. * sw.y, margins[3], 1.0 - uvMask.y);
    float maskStrokeInner = maskInner - mask;

    uv -= .5;
    uv *= patternSize;
    uv = fgRotateAspect(uv, patternRotation, sizing.u_imageAspectRatio);

    float curve = 0.;
    float patternY = uv.y / sizing.u_imageAspectRatio;
    if (u.u_shape > 4.5) {
      curve = .5 + .5 * sin(.5 * PI * uv.x) * cos(.5 * PI * patternY);
    } else if (u.u_shape > 3.5) {
      curve = 10. * abs(fract(.1 * patternY) - .5);
    } else if (u.u_shape > 2.5) {
      curve = 4. * sin(.23 * patternY);
    } else if (u.u_shape > 1.5) {
      curve = .5 + .5 * sin(.5 * uv.x) * sin(1.7 * uv.x);
    }

    float2 uvToFract = uv + curve;
    float2 fractOrigUV = fract(uv);
    float2 floorOrigUV = floor(uv);

    float x = fgSmoothFract(uvToFract.x);
    float xNonSmooth = fract(uvToFract.x) + .0001;

    float highlightsWidth = 2. * max(.001, fwidth(uvToFract.x));
    highlightsWidth += 2. * maskStrokeInner;
    float highlights = smoothstep(0., highlightsWidth, xNonSmooth);
    highlights *= smoothstep(1., 1. - highlightsWidth, xNonSmooth);
    highlights = 1. - highlights;
    highlights *= u.u_highlights;
    highlights = clamp(highlights, 0., 1.);
    highlights *= mask;

    float shadows = pow(x, 1.3);
    float distortion = 0.;
    float fadeX = 1.;
    float frameFade = 0.;

    float aa = fwidth(xNonSmooth);
    aa = max(aa, fwidth(uv.x));
    aa = max(aa, fwidth(uvToFract.x));
    aa = max(aa, .0001);

    if (u.u_distortionShape == 1.) {
      distortion = -pow(1.5 * x, 3.);
      distortion += (.5 - u.u_shift);

      frameFade = pow(1.5 * x, 3.);
      aa = max(.2, aa);
      aa += mix(.2, 0., u.u_size);
      fadeX = smoothstep(0., aa, xNonSmooth) * smoothstep(1., 1. - aa, xNonSmooth);
      distortion = mix(.5, distortion, fadeX);
    } else if (u.u_distortionShape == 2.) {
      distortion = 2. * pow(x, 2.);
      distortion -= (.5 + u.u_shift);

      frameFade = pow(abs(x - .5), 4.);
      aa = max(.2, aa);
      aa += mix(.2, 0., u.u_size);
      fadeX = smoothstep(0., aa, xNonSmooth) * smoothstep(1., 1. - aa, xNonSmooth);
      distortion = mix(.5, distortion, fadeX);
      frameFade = mix(1., frameFade, .5 * fadeX);
    } else if (u.u_distortionShape == 3.) {
      distortion = pow(2. * (xNonSmooth - .5), 6.);
      distortion -= .25;
      distortion -= u.u_shift;

      frameFade = 1. - 2. * pow(abs(x - .4), 2.);
      aa = .15;
      aa += mix(.1, 0., u.u_size);
      fadeX = smoothstep(0., aa, xNonSmooth) * smoothstep(1., 1. - aa, xNonSmooth);
      frameFade = mix(1., frameFade, fadeX);
    } else if (u.u_distortionShape == 4.) {
      x = xNonSmooth;
      distortion = sin((x + .25) * TWO_PI);
      shadows = .5 + .5 * asin(distortion) / (.5 * PI);
      distortion *= .5;
      distortion -= u.u_shift;
      frameFade = .5 + .5 * sin(x * TWO_PI);
    } else if (u.u_distortionShape == 5.) {
      distortion -= pow(abs(x), .2) * x;
      distortion += .33;
      distortion -= 3. * u.u_shift;
      distortion *= .33;

      frameFade = .3 * smoothstep(.0, 1., x);
      shadows = pow(x, 2.5);

      aa = max(.1, aa);
      aa += mix(.1, 0., u.u_size);
      fadeX = smoothstep(0., aa, xNonSmooth) * smoothstep(1., 1. - aa, xNonSmooth);
      distortion *= fadeX;
    }

    float2 dudx = dfdx(in.imageUV);
    float2 dudy = dfdy(in.imageUV);
    float2 grainUV = in.imageUV - .5;
    grainUV *= (.8 / float2(length(dudx), length(dudy)));
    grainUV += .5;
    float grain = fgValueNoise(grainUV);
    grain = smoothstep(.4, .7, grain);
    grain *= u.u_grainMixer;
    distortion = mix(distortion, 0., grain);

    shadows = min(shadows, 1.);
    shadows += maskStrokeInner;
    shadows *= mask;
    shadows = min(shadows, 1.);
    shadows *= pow(u.u_shadows, 2.);
    shadows = clamp(shadows, 0., 1.);

    distortion *= 3. * u.u_distortion;
    frameFade *= u.u_distortion;

    fractOrigUV.x += distortion;
    floorOrigUV = fgRotateAspect(floorOrigUV, -patternRotation, sizing.u_imageAspectRatio);
    fractOrigUV = fgRotateAspect(fractOrigUV, -patternRotation, sizing.u_imageAspectRatio);

    uv = (floorOrigUV + fractOrigUV) / patternSize;
    uv += pow(maskStroke, 4.);

    uv += float2(.5);

    uv = mix(in.imageUV, uv, smoothstep(0., .7, mask));
    float blur = mix(0., 50., u.u_blur);
    blur = mix(0., blur, smoothstep(.5, 1., mask));

    float edgeDistortion = mix(.0, .04, u.u_edges);
    edgeDistortion += .06 * frameFade * u.u_edges;
    edgeDistortion *= mask;
    float frame = fgGetUvFrame(uv, edgeDistortion);

    float stretch = 1. - smoothstep(0., .5, xNonSmooth) * smoothstep(1., 1. - .5, xNonSmooth);
    stretch = pow(stretch, 2.);
    stretch *= mask;
    stretch *= fgGetUvFrame(uv, .1 + .05 * mask * frameFade);
    uv.y = mix(uv.y, .5, u.u_stretch * stretch);

    float4 image = fgGetBlur(imageTex, imageSampler, uv, 1. / global.u_resolution / global.u_pixelRatio, float2(0., 1.), blur);
    image.rgb *= image.a;
    float4 backColor = u.u_colorBack;
    backColor.rgb *= backColor.a;
    float4 highlightColor = u.u_colorHighlight;
    highlightColor.rgb *= highlightColor.a;
    float4 shadowColor = u.u_colorShadow;

    float3 color = highlightColor.rgb * highlights;
    float opacity = highlightColor.a * highlights;

    shadows = mix(shadows * shadowColor.a, 0., highlights);
    color = mix(color, shadowColor.rgb * shadowColor.a, .5 * shadows);
    color += .5 * pow(shadows, .5) * shadowColor.rgb;
    opacity += shadows;
    color = clamp(color, float3(0.), float3(1.));
    opacity = clamp(opacity, 0., 1.);

    color += image.rgb * (1. - opacity) * frame;
    opacity += image.a * (1. - opacity) * frame;

    color += backColor.rgb * (1. - opacity);
    opacity += backColor.a * (1. - opacity);

    float grainOverlay = fgValueNoise(rotate(grainUV, 1.) + float2(3.));
    grainOverlay = mix(grainOverlay, fgValueNoise(rotate(grainUV, 2.) + float2(-1.)), .5);
    grainOverlay = pow(grainOverlay, 1.3);

    float grainOverlayV = grainOverlay * 2. - 1.;
    float3 grainOverlayColor = float3(step(0., grainOverlayV));
    float grainOverlayStrength = u.u_grainOverlay * abs(grainOverlayV);
    grainOverlayStrength = pow(grainOverlayStrength, .8);
    grainOverlayStrength *= mask;
    color = mix(color, grainOverlayColor, .35 * grainOverlayStrength);

    opacity += .5 * grainOverlayStrength;
    opacity = clamp(opacity, 0., 1.);

    return float4(color, opacity);
  }

  """
}
