import simd

/// Port of upstream `gem-smoke.frag`.
public enum GemSmoke {
  /// Descriptor.
  public static let descriptor = ShaderDescriptor(
    name: "gem-smoke",
    fragmentSource: source,
    usesImageTexture: true,
    usesImageMipmaps: true,
    imageResourceName: "gem-smoke"
  )

  /// Options for shape.
  public enum Shape: String, Sendable {
    case none
    case circle
    case daisy
    case diamond
    case metaballs

    var uniformValue: Float {
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
    /// Colors.
    public var colors: [String]
    /// Color back.
    public var colorBack: String
    /// Color inner.
    public var colorInner: String
    /// Inner distortion.
    public var innerDistortion: Float
    /// Outer distortion.
    public var outerDistortion: Float
    /// Outer glow.
    public var outerGlow: Float
    /// Inner glow.
    public var innerGlow: Float
    /// Offset.
    public var offset: Float
    /// Angle.
    public var angle: Float
    /// Size.
    public var size: Float
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
      colors: [String] = ["#333333", "#e7e6df"],
      colorBack: String = "#f0efea",
      colorInner: String = "#fafaf5",
      innerDistortion: Float = 0.8,
      outerDistortion: Float = 0.6,
      outerGlow: Float = 0.55,
      innerGlow: Float = 1,
      offset: Float = 0,
      angle: Float = 0,
      size: Float = 0.8,
      shape: Shape = .diamond,
      isImage: Bool = true,
      sizing: ShaderSizingParams = ShaderSizingParams(fit: .contain, scale: 0.6),
      speed: Double = 1,
      frame: Double = 0
    ) {
      self.colors = colors
      self.colorBack = colorBack
      self.colorInner = colorInner
      self.innerDistortion = innerDistortion
      self.outerDistortion = outerDistortion
      self.outerGlow = outerGlow
      self.innerGlow = innerGlow
      self.offset = offset
      self.angle = angle
      self.size = size
      self.shape = shape
      self.isImage = isImage
      self.sizing = sizing
      self.speed = speed
      self.frame = frame
    }

    /// Matches `GemSmokeUniforms` member order in the MSL source.
    public var uniforms: [UniformValue] {
      [
        .float4Array(colors.map(ShaderColor.parse), capacity: 6),
        .float(Float(max(colors.count, 1))),
        .float4(ShaderColor.parse(colorBack)),
        .float4(ShaderColor.parse(colorInner)),
        .float(innerDistortion),
        .float(outerDistortion),
        .float(outerGlow),
        .float(innerGlow),
        .float(offset),
        .float(angle),
        .float(size),
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
      name: "Fire",
      params: Params(
        colors: ["#fe5b16", "#f7ff61", "#ffffff"],
        colorBack: "#000000",
        colorInner: "#000000",
        innerDistortion: 0.6,
        outerDistortion: 0.8,
        outerGlow: 1,
        innerGlow: 0.65
      )
    ),
    Preset(
      name: "Fluorescent",
      params: Params(
        colors: ["#2fb64c", "#cdff61", "#ffffff"],
        colorBack: "#000000",
        colorInner: "#000000",
        innerDistortion: 1,
        outerDistortion: 0.8,
        outerGlow: 0,
        innerGlow: 1
      )
    ),
    Preset(
      name: "Infrared",
      params: Params(
        colors: ["#ff9900", "#fff67a", "#dcff52", "#00ffbb", "#0077ff"],
        colorBack: "#cd28dc",
        colorInner: "#00000000",
        innerDistortion: 1,
        outerDistortion: 1,
        outerGlow: 1,
        innerGlow: 1,
        offset: 0.2,
        size: 1,
        speed: 0.5
      )
    ),
  ]

  static let source = """

  struct GemSmokeUniforms {
    float4 u_colors[6];
    float u_colorsCount;
    float4 u_colorBack;
    float4 u_colorInner;
    float u_innerDistortion;
    float u_outerDistortion;
    float u_outerGlow;
    float u_innerGlow;
    float u_offset;
    float u_angle;
    float u_size;
    float u_shape;
    float u_isImage;
  };

  static float2 gsGaussBlur9x9RG(texture2d<float> imageTex, sampler imageSampler, float2 uv, float radius) {
    float2 texel = 1.0 / float2(float(imageTex.get_width()), float(imageTex.get_height()));
    float2 r = max(radius, 0.0) * texel;
    const float k[9] = {1.0, 8.0, 28.0, 56.0, 70.0, 56.0, 28.0, 8.0, 1.0};
    float2 sum = float2(0.0);

    for (int j = -4; j <= 4; ++j) {
      float wy = k[j + 4];
      for (int i = -4; i <= 4; ++i) {
        float w = k[i + 4] * wy;
        float2 off = float2(float(i) * r.x, float(j) * r.y);
        sum += w * imageTex.sample(imageSampler, uv + off).rg;
      }
    }

    return sum / 65536.0;
  }

  static float gsSst(float a, float b, float x) {
    return smoothstep(a, b, x);
  }

  fragment float4 ps_fragment(PSVertexOut in [[stage_in]],
                              constant PSGlobalUniforms& global [[buffer(0)]],
                              constant GemSmokeUniforms& u [[buffer(1)]],
                              constant PSSizingUniforms& sizing [[buffer(2)]],
                              texture2d<float> imageTex [[texture(1)]],
                              sampler imageSampler [[sampler(1)]]) {
    (void)sizing;
    float time = global.u_time;

    float roundness = 0.;
    float imgAlpha = 0.;

    if (u.u_isImage > 0.5) {
      float2 imageUV = in.imageUV;
      imageUV -= .5;
      imageUV *= .95;
      imageUV += .5;

      float2 blurred = gsGaussBlur9x9RG(imageTex, imageSampler, imageUV, 10.);
      roundness = 1. - blurred.x;
      float2 texelA = 1.0 / float2(float(imageTex.get_width()), float(imageTex.get_height()));
      const float k3[3] = {1.0, 2.0, 1.0};
      for (int j = -1; j <= 1; ++j) {
        for (int i = -1; i <= 1; ++i) {
          imgAlpha += k3[i + 1] * k3[j + 1] * imageTex.sample(imageSampler, imageUV + float2(float(i) * texelA.x, float(j) * texelA.y)).g;
        }
      }
      imgAlpha /= 16.0;
    } else {
      float2 uv = in.objectUV + .5;
      uv.y = 1. - uv.y;
      float edge = 0.;

      if (u.u_shape < 1.) {
        float2 borderUV = in.responsiveUV + .5;
        float2 mask = min(borderUV, 1. - borderUV);
        float2 pixel_thickness = min(250. / in.responsiveBoxGivenSize, float2(.5));
        float maskX = smoothstep(0.0, pixel_thickness.x, mask.x);
        float maskY = smoothstep(0.0, pixel_thickness.y, mask.y);
        maskX = pow(maskX, .25);
        maskY = pow(maskY, .25);
        edge = clamp(1. - maskX * maskY, 0., 1.);
      } else if (u.u_shape < 2.) {
        float2 shapeUV = uv - .5;
        shapeUV *= .67;
        edge = pow(clamp(3. * length(shapeUV), 0., 1.), 18.);
      } else if (u.u_shape < 3.) {
        float2 shapeUV = uv - .5;
        shapeUV *= 1.68;

        float r = length(shapeUV) * 2.;
        float a = atan2(shapeUV.y, shapeUV.x) + .2;
        r *= (1. + .05 * sin(3. * a + 2. * time));
        float f = abs(cos(a * 3.));
        edge = smoothstep(f, f + .7, r);
        edge *= edge;
      } else if (u.u_shape < 4.) {
        float2 shapeUV = uv - .5;
        shapeUV = rotate(shapeUV, .25 * PI);
        shapeUV *= 1.42;
        shapeUV += .5;
        float2 mask = min(shapeUV, 1. - shapeUV);
        float2 pixel_thickness = float2(.15);
        float maskX = smoothstep(0.0, pixel_thickness.x, mask.x);
        float maskY = smoothstep(0.0, pixel_thickness.y, mask.y);
        maskX = pow(maskX, .25);
        maskY = pow(maskY, .25);
        edge = clamp(1. - maskX * maskY, 0., 1.);
      } else if (u.u_shape < 5.) {
        float2 shapeUV = uv - .5;
        shapeUV *= 1.3;
        edge = 0.;
        for (int i = 0; i < 5; i++) {
          float fi = float(i);
          float speed = 1.5 + 2./3. * sin(fi * 12.345);
          float angle = -fi * 1.5;
          float2 dir1 = float2(cos(angle), sin(angle));
          float2 dir2 = float2(cos(angle + 1.57), sin(angle + 1.));
          float2 traj = .4 * (dir1 * sin(time * speed + fi * 1.23) + dir2 * cos(time * (speed * 0.7) + fi * 2.17));
          float d = length(shapeUV + traj);
          edge += pow(1.0 - clamp(d, 0.0, 1.0), 4.0);
        }
        edge = 1. - smoothstep(.65, .9, edge);
        edge = pow(edge, 4.);
      }

      imgAlpha = 1. - smoothstep(.9 - 2. * fwidth(edge), .9, edge);
      roundness = 1. - edge;
    }

    float2 smokeUV = in.objectUV;
    smokeUV = rotate(smokeUV, u.u_angle * PI / 180.);
    smokeUV *= mix(4., 1., u.u_size);

    float2 innerUV = smokeUV;
    float2 outerUV = smokeUV;

    innerUV.y += u.u_innerDistortion * (1. - gsSst(0., 1., length(.4 * innerUV)));
    innerUV.y -= .4 * u.u_innerDistortion;
    innerUV.y += .7 * u.u_offset * roundness;

    outerUV.y += u.u_outerDistortion * (1. - gsSst(0., 1., length(.4 * outerUV)));
    outerUV.y -= .4 * u.u_outerDistortion;

    float innerSwirl = u.u_innerDistortion * roundness;
    float outerSwirl = u.u_outerDistortion;

    for (int i = 1; i < 5; i++) {
      float fi = float(i);

      float stretchIn = max(length(dfdx(innerUV)), length(dfdy(innerUV)));
      float dampenIn = 1. / (1. + stretchIn * 8.);
      float sIn = innerSwirl * dampenIn;
      innerUV.x += sIn / fi * cos(time + fi * 2.9 * innerUV.y);
      innerUV.y += sIn / fi * cos(time + fi * 1.5 * innerUV.x);

      float stretchOut = max(length(dfdx(outerUV)), length(dfdy(outerUV)));
      float dampenOut = 1. / (1. + stretchOut * 8.);
      float sOut = outerSwirl * dampenOut;
      outerUV.x += sOut / fi * cos(time + fi * 2.9 * outerUV.y);
      outerUV.y += sOut / fi * cos(time + fi * 1.5 * outerUV.x);
    }

    float innerShape = exp(-1.5 * dot(innerUV, innerUV));
    float outerShape = exp(-1.5 * dot(outerUV, outerUV));

    float outerMask = pow(u.u_outerGlow, 2.) * (1. - imgAlpha);
    float innerMask = (.01 + .99 * u.u_innerGlow) * imgAlpha;

    innerShape *= innerMask;
    outerShape *= outerMask;

    float mixer = (innerShape + outerShape) * u.u_colorsCount;
    float4 gradient = u.u_colors[0];
    gradient.rgb *= gradient.a;

    float smokeMask = 0.;
    for (int i = 1; i < 7; i++) {
      if (i > int(u.u_colorsCount)) {
        break;
      }

      float m = gsSst(0., 1., clamp(mixer - float(i - 1), 0., 1.));
      if (i == 1) {
        smokeMask = m;
      }

      float4 c = u.u_colors[i - 1];
      c.rgb *= c.a;
      gradient = mix(gradient, c, m);
    }

    float3 color = gradient.rgb * smokeMask;
    float opacity = gradient.a * smokeMask;

    float innerOpacity = u.u_colorInner.a * imgAlpha;
    float3 innerColor = u.u_colorInner.rgb * innerOpacity;
    color += innerColor * (1.0 - opacity);
    opacity += innerOpacity * (1.0 - opacity);

    float3 backColor = u.u_colorBack.rgb * u.u_colorBack.a;
    color += backColor * (1.0 - opacity);
    opacity += u.u_colorBack.a * (1.0 - opacity);

    return float4(color, opacity);
  }

  """
}
