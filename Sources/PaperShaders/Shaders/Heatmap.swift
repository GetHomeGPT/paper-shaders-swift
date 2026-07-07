import simd

/// Port of upstream `heatmap.frag`.
public enum Heatmap {
  /// Descriptor.
  public static let descriptor = ShaderDescriptor(
    name: "heatmap",
    fragmentSource: source,
    usesImageTexture: true,
    usesImageMipmaps: true,
    imageResourceName: "heatmap"
  )

  /// Parameters used to render this shader.
  public struct Params {
    /// Colors.
    public var colors: [String]
    /// Color back.
    public var colorBack: String
    /// Angle.
    public var angle: Float
    /// Noise.
    public var noise: Float
    /// Inner glow.
    public var innerGlow: Float
    /// Outer glow.
    public var outerGlow: Float
    /// Contour.
    public var contour: Float
    /// Sizing.
    public var sizing: ShaderSizingParams
    /// Speed.
    public var speed: Double
    /// Frame.
    public var frame: Double

    /// Creates an instance.
    public init(
      colors: [String] = ["#11206a", "#1f3ba2", "#2f63e7", "#6bd7ff", "#ffe679", "#ff991e", "#ff4c00"],
      colorBack: String = "#000000",
      angle: Float = 0,
      noise: Float = 0,
      innerGlow: Float = 0.5,
      outerGlow: Float = 0.5,
      contour: Float = 0.5,
      sizing: ShaderSizingParams = ShaderSizingParams(fit: .contain, scale: 0.75),
      speed: Double = 1,
      frame: Double = 0
    ) {
      self.colors = colors
      self.colorBack = colorBack
      self.angle = angle
      self.noise = noise
      self.innerGlow = innerGlow
      self.outerGlow = outerGlow
      self.contour = contour
      self.sizing = sizing
      self.speed = speed
      self.frame = frame
    }

    /// Matches `HeatmapUniforms` member order in the MSL source.
    public var uniforms: [UniformValue] {
      [
        .float4(ShaderColor.parse(colorBack)),
        .float4Array(colors.map(ShaderColor.parse), capacity: 10),
        .float(Float(max(colors.count, 1))),
        .float(angle),
        .float(noise),
        .float(innerGlow),
        .float(outerGlow),
        .float(contour),
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
      name: "Sepia",
      params: Params(
        colors: ["#997F45", "#ffffff"],
        noise: 0.75,
        speed: 0.5
      )
    ),
  ]

  static let source = """

  struct HeatmapUniforms {
    float4 u_colorBack;
    float4 u_colors[10];
    float u_colorsCount;
    float u_angle;
    float u_noise;
    float u_innerGlow;
    float u_outerGlow;
    float u_contour;
  };

  static float hmGetImgFrame(float2 uv, float th) {
    float frame = 1.;
    frame *= smoothstep(0., th, uv.y);
    frame *= 1. - smoothstep(1. - th, 1., uv.y);
    frame *= smoothstep(0., th, uv.x);
    frame *= 1. - smoothstep(1. - th, 1., uv.x);
    return frame;
  }

  static float hmCircle(float2 uv, float2 c, float2 r) {
    return 1. - smoothstep(r[0], r[1], length(uv - c));
  }

  static float hmLst(float edge0, float edge1, float x) {
    return clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
  }

  static float hmSst(float edge0, float edge1, float x) {
    return smoothstep(edge0, edge1, x);
  }

  static float hmShadowShape(float2 uv, float t, float contour) {
    float2 scaledUV = uv;

    float posY = mix(-1., 2., t);

    scaledUV.y -= .5;
    float mainCircleScale = hmSst(0., .8, posY) * hmLst(1.4, .9, posY);
    scaledUV *= float2(1., 1. + 1.5 * mainCircleScale);
    scaledUV.y += .5;

    float innerR = .4;
    float outerR = 1. - .3 * (hmSst(.1, .2, t) * (1. - hmSst(.2, .5, t)));
    float s = hmCircle(scaledUV, float2(.5, posY - .2), float2(innerR, outerR));
    s = pow(s, 1.4);
    s *= 1.2;

    {
      float pos = posY - uv.y;
      float edge = 1.2;
      float topFlattener = hmLst(-.4, 0., pos) * (1. - hmSst(.0, edge, pos));
      topFlattener = pow(topFlattener, 3.);
      float topFlattenerMixer = (1. - hmSst(.0, .3, pos));
      s = mix(topFlattener, s, topFlattenerMixer);
    }

    {
      float visibility = hmSst(.6, .7, t) * (1. - hmSst(.8, .9, t));
      float angle = -2. - t * TWO_PI;
      float rightCircle = hmCircle(uv, float2(.95 - .2 * cos(angle), .4 - .1 * sin(angle)), float2(.15, .3));
      rightCircle *= visibility;
      s = mix(s, 0., rightCircle);
    }

    {
      float topCircle = hmCircle(uv, float2(.5, .19), float2(.05, .25));
      topCircle += 2. * contour * hmCircle(uv, float2(.5, .19), float2(.2, .5));
      float visibility = .55 * hmSst(.2, .3, t) * (1. - hmSst(.3, .45, t));
      topCircle *= visibility;
      s = mix(s, 0., topCircle);
    }

    float leafMask = hmCircle(uv, float2(.53, .13), float2(.08, .19));
    leafMask = mix(leafMask, 0., 1. - hmSst(.4, .54, uv.x));
    leafMask = mix(0., leafMask, hmSst(.0, .2, uv.y));
    leafMask *= (hmSst(.5, 1.1, posY) * hmSst(1.5, 1.3, posY));
    s += leafMask;

    {
      float visibility = hmSst(.0, .4, t) * (1. - hmSst(.6, .8, t));
      s = mix(s, 0., visibility * hmCircle(uv, float2(.52, .92), float2(.09, .25)));
    }

    {
      float pos = hmSst(.0, .6, t) * (1. - hmSst(.6, 1., t));
      s = mix(s, .5, hmCircle(uv, float2(.0, 1.2 - .5 * pos), float2(.1, .3)));
      s = mix(s, .0, hmCircle(uv, float2(1., .5 + .5 * pos), float2(.1, .3)));

      s = mix(s, 1., hmCircle(uv, float2(.95, .2 + .2 * hmSst(.3, .4, t) * hmSst(.7, .5, t)), float2(.07, .22)));
      s = mix(s, 1., hmCircle(uv, float2(.95, .2 + .2 * hmSst(.3, .4, t) * (1. - hmSst(.5, .7, t))), float2(.07, .22)));
      s /= max(1e-4, hmSst(1., .85, uv.y));
    }

    s = min(1., s);
    return s;
  }

  static float hmBlurEdge3x3(texture2d<float> imageTex, sampler imageSampler, float2 uv, float radius, float centerSample) {
    float2 texel = 1.0 / float2(float(imageTex.get_width()), float(imageTex.get_height()));
    float2 r = radius * texel;

    float w1 = 1.0, w2 = 2.0, w4 = 4.0;
    float norm = 16.0;
    float sum = w4 * centerSample;

    sum += w2 * imageTex.sample(imageSampler, uv + float2(0.0, -r.y)).g;
    sum += w2 * imageTex.sample(imageSampler, uv + float2(0.0, r.y)).g;
    sum += w2 * imageTex.sample(imageSampler, uv + float2(-r.x, 0.0)).g;
    sum += w2 * imageTex.sample(imageSampler, uv + float2(r.x, 0.0)).g;

    sum += w1 * imageTex.sample(imageSampler, uv + float2(-r.x, -r.y)).g;
    sum += w1 * imageTex.sample(imageSampler, uv + float2(r.x, -r.y)).g;
    sum += w1 * imageTex.sample(imageSampler, uv + float2(-r.x, r.y)).g;
    sum += w1 * imageTex.sample(imageSampler, uv + float2(r.x, r.y)).g;

    return sum / norm;
  }

  fragment float4 ps_fragment(PSVertexOut in [[stage_in]],
                              constant PSGlobalUniforms& global [[buffer(0)]],
                              constant HeatmapUniforms& u [[buffer(1)]],
                              constant PSSizingUniforms& sizing [[buffer(2)]],
                              texture2d<float> imageTex [[texture(1)]],
                              sampler imageSampler [[sampler(1)]]) {
    (void)sizing;
    float2 uv = in.objectUV + .5;
    uv.y = 1. - uv.y;

    float2 imgUV = in.imageUV;
    imgUV -= .5;
    imgUV *= 0.5714285714285714;
    imgUV += .5;
    float imgSoftFrame = hmGetImgFrame(imgUV, .03);

    float4 img = imageTex.sample(imageSampler, imgUV);

    if (img.a == 0.) {
      return u.u_colorBack;
    }

    float t = .1 * global.u_time;
    t -= .3;

    float tCopy = t + 1. / 3.;
    float tCopy2 = t + 2. / 3.;

    t = glsl_mod(t, 1.);
    tCopy = glsl_mod(tCopy, 1.);
    tCopy2 = glsl_mod(tCopy2, 1.);

    float2 animationUV = imgUV - float2(.5);
    float angle = -u.u_angle * PI / 180.;
    float cosA = cos(angle);
    float sinA = sin(angle);
    animationUV = float2(
      animationUV.x * cosA - animationUV.y * sinA,
      animationUV.x * sinA + animationUV.y * cosA
    ) + float2(.5);

    float shape = img.x;

    img.y = hmBlurEdge3x3(imageTex, imageSampler, imgUV, 8., img.y);

    float outerBlur = 1. - mix(1., img.y, shape);
    float innerBlur = mix(img.y, 0., shape);
    float contour = mix(img.z, 0., shape);

    outerBlur *= imgSoftFrame;

    float shadow = hmShadowShape(animationUV, t, innerBlur);
    float shadowCopy = hmShadowShape(animationUV, tCopy, innerBlur);
    float shadowCopy2 = hmShadowShape(animationUV, tCopy2, innerBlur);

    float inner = .8 + .8 * innerBlur;
    inner = mix(inner, 0., shadow);
    inner = mix(inner, 0., shadowCopy);
    inner = mix(inner, 0., shadowCopy2);

    inner *= mix(0., 2., u.u_innerGlow);

    inner += (u.u_contour * 2.) * contour;
    inner = min(1., inner);
    inner *= (1. - shape);

    float outer = 0.;
    {
      t *= 3.;
      t = glsl_mod(t - .1, 1.);

      outer = .9 * pow(outerBlur, .8);
      float y = glsl_mod(animationUV.y - t, 1.);
      float animatedMask = hmSst(.3, .65, y) * (1. - hmSst(.65, 1., y));
      animatedMask = .5 + animatedMask;
      outer *= animatedMask;
      outer *= mix(0., 5., pow(u.u_outerGlow, 2.));
      outer *= imgSoftFrame;
    }

    inner = pow(inner, 1.2);
    float heat = clamp(inner + outer, 0., 1.);

    heat += (.005 + .35 * u.u_noise) * (fract(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453123) - .5);

    float mixer = heat * u.u_colorsCount;
    float4 gradient = u.u_colors[0];
    gradient.rgb *= gradient.a;
    float outerShape = 0.;
    for (int i = 1; i < 11; i++) {
      if (i > int(u.u_colorsCount)) break;
      float m = clamp(mixer - float(i - 1), 0., 1.);
      if (i == 1) {
        outerShape = m;
      }
      float4 c = u.u_colors[i - 1];
      c.rgb *= c.a;
      gradient = mix(gradient, c, m);
    }

    float3 color = gradient.rgb * outerShape;
    float opacity = gradient.a * outerShape;

    float3 bgColor = u.u_colorBack.rgb * u.u_colorBack.a;
    color = color + bgColor * (1.0 - opacity);
    opacity = opacity + u.u_colorBack.a * (1.0 - opacity);

    color += .02 * (fract(sin(dot(uv + 1., float2(12.9898, 78.233))) * 43758.5453123) - .5);

    return float4(color, opacity);
  }
  """
}
