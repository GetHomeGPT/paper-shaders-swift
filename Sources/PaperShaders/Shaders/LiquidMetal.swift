import simd

/// Port of upstream `liquid-metal.frag`.
public enum LiquidMetal {
  /// Descriptor.
  public static let descriptor = ShaderDescriptor(
    name: "liquid-metal",
    fragmentSource: source,
    usesImageTexture: true,
    usesImageMipmaps: true,
    imageResourceName: "liquid-metal"
  )

  /// Options for shape.
  public enum Shape: String, Sendable {
    case none
    case circle
    case daisy
    case diamond
    case metaballs

    /// Value passed to the `u_shape` uniform (upstream `LiquidMetalShapes`).
    public var uniformValue: Float {
      switch self {
      case .none: return 0
      case .circle: return 1
      case .daisy: return 2
      case .diamond: return 3
      case .metaballs: return 4
      }
    }
  }

  /// Parameters used to render this shader.
  public struct Params {
    /// Color back.
    public var colorBack: String
    /// Color tint.
    public var colorTint: String
    /// Softness.
    public var softness: Float
    /// Repetition.
    public var repetition: Float
    /// Shift red.
    public var shiftRed: Float
    /// Shift blue.
    public var shiftBlue: Float
    /// Distortion.
    public var distortion: Float
    /// Contour.
    public var contour: Float
    /// Angle.
    public var angle: Float
    /// Shape.
    public var shape: Shape
    /// Is image.
    public var isImage: Bool
    /// Sizing.
    public var sizing: ShaderSizingParams
    /// Speed.
    public var speed: Double
    /// Frame.
    public var frame: Double

    /// Creates an instance.
    public init(
      colorBack: String = "#AAAAAC",
      colorTint: String = "#ffffff",
      softness: Float = 0.1,
      repetition: Float = 2,
      shiftRed: Float = 0.3,
      shiftBlue: Float = 0.3,
      distortion: Float = 0.07,
      contour: Float = 0.4,
      angle: Float = 70,
      shape: Shape = .diamond,
      isImage: Bool = true,
      sizing: ShaderSizingParams = ShaderSizingParams(fit: .contain, scale: 0.6),
      speed: Double = 1,
      frame: Double = 0
    ) {
      self.colorBack = colorBack
      self.colorTint = colorTint
      self.softness = softness
      self.repetition = repetition
      self.shiftRed = shiftRed
      self.shiftBlue = shiftBlue
      self.distortion = distortion
      self.contour = contour
      self.angle = angle
      self.shape = shape
      self.isImage = isImage
      self.sizing = sizing
      self.speed = speed
      self.frame = frame
    }

    /// Matches `LiquidMetalUniforms` member order in the MSL source.
    public var uniforms: [UniformValue] {
      [
        .float4(ShaderColor.parse(colorBack)),
        .float4(ShaderColor.parse(colorTint)),
        .float(softness),
        .float(repetition),
        .float(shiftRed),
        .float(shiftBlue),
        .float(distortion),
        .float(contour),
        .float(angle),
        .float(shape.uniformValue),
        .float(isImage ? 1 : 0),
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
      name: "Noir",
      params: Params(
        colorBack: "#000000",
        colorTint: "#606060",
        softness: 0.45,
        repetition: 1.5,
        shiftRed: 0,
        shiftBlue: 0,
        distortion: 0,
        contour: 0,
        angle: 90
      )
    ),
    Preset(
      name: "Backdrop",
      params: Params(
        colorBack: "#AAAAAC",
        colorTint: "#ffffff",
        softness: 0.05,
        repetition: 1.5,
        shiftRed: 0.3,
        shiftBlue: 0.3,
        distortion: 0.1,
        contour: 0.4,
        angle: 90,
        shape: .none,
        sizing: ShaderSizingParams(fit: .contain, scale: 1)
      )
    ),
    Preset(
      name: "Stripes",
      params: Params(
        colorBack: "#000000",
        colorTint: "#2c5d72",
        softness: 0.8,
        repetition: 6,
        shiftRed: 1,
        shiftBlue: -1,
        distortion: 0.4,
        contour: 0.4,
        angle: 0,
        shape: .circle
      )
    ),
  ]

  static let source = """

  struct LiquidMetalUniforms {
    float4 u_colorBack;
    float4 u_colorTint;
    float u_softness;
    float u_repetition;
    float u_shiftRed;
    float u_shiftBlue;
    float u_distortion;
    float u_contour;
    float u_angle;
    float u_shape;
    float u_isImage;
  };

  static float lmGetColorChanges(float c1, float c2, float stripeP, float3 w,
                                 float blur, float bump, float tint,
                                 constant LiquidMetalUniforms& u) {
    float ch = mix(c2, c1, smoothstep(.0, 2. * blur, stripeP));

    float border = w[0];
    ch = mix(ch, c2, smoothstep(border, border + 2. * blur, stripeP));

    if (u.u_isImage > 0.5) {
      bump = smoothstep(.2, .8, bump);
    }
    border = w[0] + .4 * (1. - bump) * w[1];
    ch = mix(ch, c1, smoothstep(border, border + 2. * blur, stripeP));

    border = w[0] + .5 * (1. - bump) * w[1];
    ch = mix(ch, c2, smoothstep(border, border + 2. * blur, stripeP));

    border = w[0] + w[1];
    ch = mix(ch, c1, smoothstep(border, border + 2. * blur, stripeP));

    float gradientT = (stripeP - w[0] - w[1]) / w[2];
    float gradient = mix(c1, c2, smoothstep(0., 1., gradientT));
    ch = mix(ch, gradient, smoothstep(border, border + .5 * blur, stripeP));

    ch = mix(ch, 1. - min(1., (1. - ch) / max(tint, 0.0001)), u.u_colorTint.a);
    return ch;
  }

  static float lmGetImgFrame(float2 uv, float th) {
    if (th <= 0.0) {
      float left = step(0., uv.x);
      float right = 1. - step(1., uv.x);
      float bottom = step(0., uv.y);
      float top = 1. - step(1., uv.y);
      return left * right * bottom * top;
    }

    float frame = 1.;
    frame *= smoothstep(0., th, uv.y);
    frame *= 1.0 - smoothstep(1. - th, 1., uv.y);
    frame *= smoothstep(0., th, uv.x);
    frame *= 1.0 - smoothstep(1. - th, 1., uv.x);
    return frame;
  }

  static float lmBlurEdge3x3(texture2d<float> imageTex, sampler imageSampler,
                             float2 uv, float radius, float centerSample) {
    float2 texel = 1.0 / float2(float(imageTex.get_width()), float(imageTex.get_height()));
    float2 r = radius * texel;

    float w1 = 1.0, w2 = 2.0, w4 = 4.0;
    float norm = 16.0;
    float sum = w4 * centerSample;

    sum += w2 * imageTex.sample(imageSampler, uv + float2(0.0, -r.y)).r;
    sum += w2 * imageTex.sample(imageSampler, uv + float2(0.0, r.y)).r;
    sum += w2 * imageTex.sample(imageSampler, uv + float2(-r.x, 0.0)).r;
    sum += w2 * imageTex.sample(imageSampler, uv + float2(r.x, 0.0)).r;

    sum += w1 * imageTex.sample(imageSampler, uv + float2(-r.x, -r.y)).r;
    sum += w1 * imageTex.sample(imageSampler, uv + float2(r.x, -r.y)).r;
    sum += w1 * imageTex.sample(imageSampler, uv + float2(-r.x, r.y)).r;
    sum += w1 * imageTex.sample(imageSampler, uv + float2(r.x, r.y)).r;

    return sum / norm;
  }

  fragment float4 ps_fragment(PSVertexOut in [[stage_in]],
                              constant PSGlobalUniforms& global [[buffer(0)]],
                              constant LiquidMetalUniforms& u [[buffer(1)]],
                              constant PSSizingUniforms& sizing [[buffer(2)]],
                              texture2d<float> imageTex [[texture(1)]],
                              sampler imageSampler [[sampler(1)]]) {
    (void)sizing;
    float2 fragCoordGL = float2(in.position.x, global.u_resolution.y - in.position.y);

    const float firstFrameOffset = 2.8;
    float t = .3 * (global.u_time + firstFrameOffset);

    float2 uv = in.imageUV;
    float4 img = imageTex.sample(imageSampler, uv);

    if (u.u_isImage <= 0.5) {
      uv = in.objectUV + .5;
      uv.y = 1. - uv.y;
    }

    float cycleWidth = u.u_repetition;
    float edge = 0.;

    float2 rotatedUV = uv - float2(.5);
    float angle = (-u.u_angle + 70.) * PI / 180.;
    float cosA = cos(angle);
    float sinA = sin(angle);
    rotatedUV = float2(
      rotatedUV.x * cosA - rotatedUV.y * sinA,
      rotatedUV.x * sinA + rotatedUV.y * cosA
    ) + float2(.5);

    if (u.u_isImage > 0.5) {
      float edgeRaw = img.r;
      edge = lmBlurEdge3x3(imageTex, imageSampler, uv, 6., edgeRaw);
      edge = pow(edge, 1.6);
      edge *= mix(0.0, 1.0, smoothstep(0.0, 0.4, u.u_contour));
    } else {
      if (u.u_shape < 1.) {
        float2 borderUV = in.responsiveUV + .5;
        float ratio = in.responsiveBoxGivenSize.x / in.responsiveBoxGivenSize.y;
        float2 mask = min(borderUV, 1. - borderUV);
        float2 pixelThickness = min(250. / in.responsiveBoxGivenSize, float2(.5));
        float maskX = smoothstep(0.0, pixelThickness.x, mask.x);
        float maskY = smoothstep(0.0, pixelThickness.y, mask.y);
        maskX = pow(maskX, .25);
        maskY = pow(maskY, .25);
        edge = clamp(1. - maskX * maskY, 0., 1.);

        uv = in.responsiveUV;
        if (ratio > 1.) {
          uv.y /= ratio;
        } else {
          uv.x *= ratio;
        }
        uv += .5;
        uv.y = 1. - uv.y;

        cycleWidth *= 2.;
      } else if (u.u_shape < 2.) {
        float2 shapeUV = uv - .5;
        shapeUV *= .67;
        edge = pow(clamp(3. * length(shapeUV), 0., 1.), 18.);
      } else if (u.u_shape < 3.) {
        float2 shapeUV = uv - .5;
        shapeUV *= 1.68;

        float r = length(shapeUV) * 2.;
        float a = atan2(shapeUV.y, shapeUV.x) + .2;
        r *= (1. + .05 * sin(3. * a + 2. * t));
        float f = abs(cos(a * 3.));
        edge = smoothstep(f, f + .7, r);
        edge *= edge;

        uv *= .8;
        cycleWidth *= 1.6;
      } else if (u.u_shape < 4.) {
        float2 shapeUV = uv - .5;
        shapeUV = rotate(shapeUV, .25 * PI);
        shapeUV *= 1.42;
        shapeUV += .5;
        float2 mask = min(shapeUV, 1. - shapeUV);
        float2 pixelThickness = float2(.15);
        float maskX = smoothstep(0.0, pixelThickness.x, mask.x);
        float maskY = smoothstep(0.0, pixelThickness.y, mask.y);
        maskX = pow(maskX, .25);
        maskY = pow(maskY, .25);
        edge = clamp(1. - maskX * maskY, 0., 1.);
      } else if (u.u_shape < 5.) {
        float2 shapeUV = uv - .5;
        shapeUV *= 1.3;
        edge = 0.;
        for (int i = 0; i < 5; i++) {
          float fi = float(i);
          float speed = 1.5 + 2. / 3. * sin(fi * 12.345);
          float angle2 = -fi * 1.5;
          float2 dir1 = float2(cos(angle2), sin(angle2));
          float2 dir2 = float2(cos(angle2 + 1.57), sin(angle2 + 1.));
          float2 traj = .4 * (dir1 * sin(t * speed + fi * 1.23) + dir2 * cos(t * (speed * 0.7) + fi * 2.17));
          float d = length(shapeUV + traj);
          edge += pow(1.0 - clamp(d, 0.0, 1.0), 4.0);
        }
        edge = 1. - smoothstep(.65, .9, edge);
        edge = pow(edge, 4.);
      }

      edge = mix(smoothstep(.9 - 2. * fwidth(edge), .9, edge), edge, smoothstep(0.0, 0.4, u.u_contour));
    }

    float opacity = 0.;
    if (u.u_isImage > 0.5) {
      opacity = img.g;
      float frame = lmGetImgFrame(in.imageUV, 0.);
      opacity *= frame;
    } else {
      opacity = 1. - smoothstep(.9 - 2. * fwidth(edge), .9, edge);
      if (u.u_shape < 2.) {
        edge = 1.2 * edge;
      } else if (u.u_shape < 5.) {
        edge = 1.8 * pow(edge, 1.5);
      }
    }

    float diagBLtoTR = rotatedUV.x - rotatedUV.y;
    float diagTLtoBR = rotatedUV.x + rotatedUV.y;

    float3 color = float3(0.);
    float3 color1 = float3(.98, .98, 1.);
    float3 color2 = float3(.1, .1, .1 + .1 * smoothstep(.7, 1.3, diagTLtoBR));

    float2 gradUV = uv - .5;

    float dist = length(gradUV + float2(0., .2 * diagBLtoTR));
    gradUV = rotate(gradUV, (.25 - .2 * diagBLtoTR) * PI);
    float direction = gradUV.x;

    float bump = pow(1.8 * dist, 1.2);
    bump = 1. - bump;
    bump *= pow(uv.y, .3);

    float thinStrip1Ratio = .12 / cycleWidth * (1. - .4 * bump);
    float thinStrip2Ratio = .07 / cycleWidth * (1. + .4 * bump);
    float wideStripRatio = (1. - thinStrip1Ratio - thinStrip2Ratio);

    float thinStrip1Width = cycleWidth * thinStrip1Ratio;
    float thinStrip2Width = cycleWidth * thinStrip2Ratio;

    float noise = snoise(uv - t);

    edge += (1. - edge) * u.u_distortion * noise;

    direction += diagBLtoTR;
    float contour = 0.;
    direction -= 2. * noise * diagBLtoTR * (smoothstep(0., 1., edge) * (1.0 - smoothstep(0., 1., edge)));
    direction *= mix(1., 1. - edge, smoothstep(.5, 1., u.u_contour));
    direction -= 1.7 * edge * smoothstep(.5, 1., u.u_contour);
    direction += .2 * pow(u.u_contour, 4.) * (1.0 - smoothstep(0., 1., edge));

    bump *= clamp(pow(uv.y, .1), .3, 1.);
    direction *= (.1 + (1.1 - edge) * bump);

    direction *= (.4 + .6 * (1.0 - smoothstep(.5, 1., edge)));
    direction += .18 * (smoothstep(.1, .2, uv.y) * (1.0 - smoothstep(.2, .4, uv.y)));
    direction += .03 * (smoothstep(.1, .2, 1. - uv.y) * (1.0 - smoothstep(.2, .4, 1. - uv.y)));

    direction *= (.5 + .5 * pow(uv.y, 2.));
    direction *= cycleWidth;
    direction -= t;

    float colorDispersion = (1. - bump);
    colorDispersion = clamp(colorDispersion, 0., 1.);
    float dispersionRed = colorDispersion;
    dispersionRed += .03 * bump * noise;
    dispersionRed += 5. * (smoothstep(-.1, .2, uv.y) * (1.0 - smoothstep(.1, .5, uv.y))) * (smoothstep(.4, .6, bump) * (1.0 - smoothstep(.4, 1., bump)));
    dispersionRed -= diagBLtoTR;

    float dispersionBlue = colorDispersion;
    dispersionBlue *= 1.3;
    dispersionBlue += (smoothstep(0., .4, uv.y) * (1.0 - smoothstep(.1, .8, uv.y))) * (smoothstep(.4, .6, bump) * (1.0 - smoothstep(.4, .8, bump)));
    dispersionBlue -= .2 * edge;

    dispersionRed *= (u.u_shiftRed / 20.);
    dispersionBlue *= (u.u_shiftBlue / 20.);

    float blur = 0.;
    float rExtraBlur = 0.;
    float gExtraBlur = 0.;
    if (u.u_isImage > 0.5) {
      float softness = 0.05 * u.u_softness;
      blur = softness + .5 * smoothstep(1., 10., u.u_repetition) * smoothstep(.0, 1., edge);
      float smallCanvasT = 1.0 - smoothstep(100., 500., min(global.u_resolution.x, global.u_resolution.y));
      blur += smallCanvasT * smoothstep(.0, 1., edge);
      rExtraBlur = softness * (0.05 + .1 * (u.u_shiftRed / 20.) * bump);
      gExtraBlur = softness * 0.05 / max(0.001, abs(1. - diagBLtoTR));
    } else {
      blur = u.u_softness / 15. + .3 * contour;
    }

    float3 w = float3(thinStrip1Width, thinStrip2Width, wideStripRatio);
    w[1] -= .02 * smoothstep(.0, 1., edge + bump);
    float stripeR = fract(direction + dispersionRed);
    float r = lmGetColorChanges(color1.r, color2.r, stripeR, w, blur + fwidth(stripeR) + rExtraBlur, bump, u.u_colorTint.r, u);
    float stripeG = fract(direction);
    float g = lmGetColorChanges(color1.g, color2.g, stripeG, w, blur + fwidth(stripeG) + gExtraBlur, bump, u.u_colorTint.g, u);
    float stripeB = fract(direction - dispersionBlue);
    float b = lmGetColorChanges(color1.b, color2.b, stripeB, w, blur + fwidth(stripeB), bump, u.u_colorTint.b, u);

    color = float3(r, g, b);
    color *= opacity;

    float3 bgColor = u.u_colorBack.rgb * u.u_colorBack.a;
    color = color + bgColor * (1. - opacity);
    opacity = opacity + u.u_colorBack.a * (1. - opacity);

    color += 1. / 256. * (fract(sin(dot(.014 * fragCoordGL, float2(12.9898, 78.233))) * 43758.5453123) - .5);

    return float4(color, opacity);
  }
  """
}
