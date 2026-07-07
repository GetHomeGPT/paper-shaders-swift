import simd

/// Port of upstream `dithering.frag`. Declares no varyings: it recomputes
/// its UVs per fragment from `gl_FragCoord` and the sizing uniforms, which
/// the renderer also binds at fragment buffer(2).
public enum Dithering {
  /// Descriptor.
  public static let descriptor = ShaderDescriptor(
    name: "dithering",
    fragmentSource: source
  )

  /// Options for shape.
  public enum Shape: String, Sendable {
    case simplex
    case warp
    case dots
    case wave
    case ripple
    case swirl
    case sphere

    /// Value passed to the `u_shape` uniform (upstream `DitheringShapes`).
    public var uniformValue: Float {
      switch self {
      case .simplex: return 1
      case .warp: return 2
      case .dots: return 3
      case .wave: return 4
      case .ripple: return 5
      case .swirl: return 6
      case .sphere: return 7
      }
    }
  }

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
    /// Color back.
    public var colorBack: String
    /// Color front.
    public var colorFront: String
    /// Shape.
    public var shape: Shape
    /// Type.
    public var type: DitherType
    /// Size.
    public var size: Float
    /// Sizing.
    public var sizing: ShaderSizingParams
    /// Speed.
    public var speed: Double
    /// Frame.
    public var frame: Double

    /// Creates an instance.
    public init(
      colorBack: String = "#000000",
      colorFront: String = "#00b2ff",
      shape: Shape = .sphere,
      type: DitherType = .bayer4x4,
      size: Float = 2,
      sizing: ShaderSizingParams = ShaderSizingParams(fit: .none, scale: 0.6),
      speed: Double = 1,
      frame: Double = 0
    ) {
      self.colorBack = colorBack
      self.colorFront = colorFront
      self.shape = shape
      self.type = type
      self.size = size
      self.sizing = sizing
      self.speed = speed
      self.frame = frame
    }

    /// Matches `DitheringUniforms` member order in the MSL source.
    public var uniforms: [UniformValue] {
      [
        .float(size),
        .float4(ShaderColor.parse(colorBack)),
        .float4(ShaderColor.parse(colorFront)),
        .float(shape.uniformValue),
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
      name: "Warp",
      params: Params(
        colorBack: "#301c2a",
        colorFront: "#56ae6c",
        shape: .warp,
        type: .bayer4x4,
        size: 2.5,
        sizing: .defaultObject
      )
    ),
    Preset(
      name: "Sine Wave",
      params: Params(
        colorBack: "#730d54",
        colorFront: "#00becc",
        shape: .wave,
        type: .bayer4x4,
        size: 11,
        sizing: ShaderSizingParams(fit: .none, scale: 1.2)
      )
    ),
    Preset(
      name: "Ripple",
      params: Params(
        colorBack: "#603520",
        colorFront: "#c67953",
        shape: .ripple,
        type: .bayer2x2,
        size: 3,
        sizing: .defaultObject
      )
    ),
    Preset(
      name: "Bugs",
      params: Params(
        colorBack: "#000000",
        colorFront: "#008000",
        shape: .dots,
        type: .random,
        size: 9,
        sizing: .defaultPattern
      )
    ),
    Preset(
      name: "Swirl",
      params: Params(
        colorBack: "#00000000",
        colorFront: "#47a8e1",
        shape: .swirl,
        type: .bayer8x8,
        size: 2,
        sizing: .defaultObject
      )
    ),
  ]

  static let source = """

  struct DitheringUniforms {
    float u_pxSize;
    float4 u_colorBack;
    float4 u_colorFront;
    float u_shape;
    float u_type;
  };

  static float getSimplexNoise(float2 uv, float t) {
    float noise = .5 * snoise(uv - float2(0., .3 * t));
    noise += .5 * snoise(2. * uv + float2(0., .32 * t));

    return noise;
  }

  constant int bayer2x2[4] = {0, 2, 3, 1};
  constant int bayer4x4[16] = {
  0, 8, 2, 10,
  12, 4, 14, 6,
  3, 11, 1, 9,
  15, 7, 13, 5
  };

  constant int bayer8x8[64] = {
  0, 32, 8, 40, 2, 34, 10, 42,
  48, 16, 56, 24, 50, 18, 58, 26,
  12, 44, 4, 36, 14, 46, 6, 38,
  60, 28, 52, 20, 62, 30, 54, 22,
  3, 35, 11, 43, 1, 33, 9, 41,
  51, 19, 59, 27, 49, 17, 57, 25,
  15, 47, 7, 39, 13, 45, 5, 37,
  63, 31, 55, 23, 61, 29, 53, 21
  };

  static float getBayerValue(float2 uv, int size) {
    int2 pos = int2(fract(uv / float(size)) * float(size));
    int index = pos.y * size + pos.x;

    if (size == 2) {
      return float(bayer2x2[index]) / 4.0;
    } else if (size == 4) {
      return float(bayer4x4[index]) / 16.0;
    } else if (size == 8) {
      return float(bayer8x8[index]) / 64.0;
    }
    return 0.0;
  }

  fragment float4 ps_fragment(PSVertexOut in [[stage_in]],
                              constant PSGlobalUniforms& global [[buffer(0)]],
                              constant DitheringUniforms& u [[buffer(1)]],
                              constant PSSizingUniforms& sizing [[buffer(2)]]) {
    float t = .5 * global.u_time;

    // gl_FragCoord has a bottom-left origin, Metal's position is top-left
    float2 fragCoordGL = float2(in.position.x, global.u_resolution.y - in.position.y);

    float pxSize = u.u_pxSize * global.u_pixelRatio;
    float2 pxSizeUV = fragCoordGL - .5 * global.u_resolution;
    pxSizeUV /= pxSize;
    float2 canvasPixelizedUV = (floor(pxSizeUV) + .5) * pxSize;
    float2 normalizedUV = canvasPixelizedUV / global.u_resolution;

    float2 ditheringNoiseUV = canvasPixelizedUV;
    float2 shapeUV = normalizedUV;

    float2 boxOrigin = float2(.5 - sizing.u_originX, sizing.u_originY - .5);
    float2 givenBoxSize = float2(sizing.u_worldWidth, sizing.u_worldHeight);
    givenBoxSize = max(givenBoxSize, float2(1.)) * global.u_pixelRatio;
    float r = sizing.u_rotation * PI / 180.;
    float2x2 graphicRotation = float2x2(float2(cos(r), sin(r)), float2(-sin(r), cos(r)));

    float patternBoxRatio = givenBoxSize.x / givenBoxSize.y;
    float2 boxSize = float2(
    (sizing.u_worldWidth == 0.) ? global.u_resolution.x : givenBoxSize.x,
    (sizing.u_worldHeight == 0.) ? global.u_resolution.y : givenBoxSize.y
    );

    if (u.u_shape > 3.5) {
      float2 objectBoxSize = float2(0.);
      // fit = none
      objectBoxSize.x = min(boxSize.x, boxSize.y);
      if (sizing.u_fit == 1.) { // fit = contain
        objectBoxSize.x = min(global.u_resolution.x, global.u_resolution.y);
      } else if (sizing.u_fit == 2.) { // fit = cover
        objectBoxSize.x = max(global.u_resolution.x, global.u_resolution.y);
      }
      objectBoxSize.y = objectBoxSize.x;
      float2 objectWorldScale = global.u_resolution / objectBoxSize;

      shapeUV *= objectWorldScale;
      shapeUV += boxOrigin * (objectWorldScale - 1.);
      shapeUV += float2(-sizing.u_offsetX, sizing.u_offsetY);
      shapeUV /= sizing.u_scale;
      shapeUV = graphicRotation * shapeUV;
    } else {
      float2 patternBoxSize = float2(0.);
      // fit = none
      patternBoxSize.x = patternBoxRatio * min(boxSize.x / patternBoxRatio, boxSize.y);
      float patternWorldNoFitBoxWidth = patternBoxSize.x;
      if (sizing.u_fit == 1.) { // fit = contain
        patternBoxSize.x = patternBoxRatio * min(global.u_resolution.x / patternBoxRatio, global.u_resolution.y);
      } else if (sizing.u_fit == 2.) { // fit = cover
        patternBoxSize.x = patternBoxRatio * max(global.u_resolution.x / patternBoxRatio, global.u_resolution.y);
      }
      patternBoxSize.y = patternBoxSize.x / patternBoxRatio;
      float2 patternWorldScale = global.u_resolution / patternBoxSize;

      shapeUV += float2(-sizing.u_offsetX, sizing.u_offsetY) / patternWorldScale;
      shapeUV += boxOrigin;
      shapeUV -= boxOrigin / patternWorldScale;
      shapeUV *= global.u_resolution;
      shapeUV /= global.u_pixelRatio;
      if (sizing.u_fit > 0.) {
        shapeUV *= (patternWorldNoFitBoxWidth / patternBoxSize.x);
      }
      shapeUV /= sizing.u_scale;
      shapeUV = graphicRotation * shapeUV;
      shapeUV += boxOrigin / patternWorldScale;
      shapeUV -= boxOrigin;
      shapeUV += .5;
    }

    float shape = 0.;
    if (u.u_shape < 1.5) {
      // Simplex noise
      shapeUV *= .001;

      shape = 0.5 + 0.5 * getSimplexNoise(shapeUV, t);
      shape = smoothstep(0.3, 0.9, shape);

    } else if (u.u_shape < 2.5) {
      // Warp
      shapeUV *= .003;

      for (float i = 1.0; i < 6.0; i++) {
        shapeUV.x += 0.6 / i * cos(i * 2.5 * shapeUV.y + t);
        shapeUV.y += 0.6 / i * cos(i * 1.5 * shapeUV.x + t);
      }

      shape = .15 / max(0.001, abs(sin(t - shapeUV.y - shapeUV.x)));
      shape = smoothstep(0.02, 1., shape);

    } else if (u.u_shape < 3.5) {
      // Dots
      shapeUV *= .05;

      float stripeIdx = floor(2. * shapeUV.x / TWO_PI);
      float rand = hash11(stripeIdx * 10.);
      rand = sign(rand - .5) * pow(.1 + abs(rand), .4);
      shape = sin(shapeUV.x) * cos(shapeUV.y - 5. * rand * t);
      shape = pow(abs(shape), 6.);

    } else if (u.u_shape < 4.5) {
      // Sine wave
      shapeUV *= 4.;

      float wave = cos(.5 * shapeUV.x - 2. * t) * sin(1.5 * shapeUV.x + t) * (.75 + .25 * cos(3. * t));
      shape = 1. - smoothstep(-1., 1., shapeUV.y + wave);

    } else if (u.u_shape < 5.5) {
      // Ripple

      float dist = length(shapeUV);
      float waves = sin(pow(dist, 1.7) * 7. - 3. * t) * .5 + .5;
      shape = waves;

    } else if (u.u_shape < 6.5) {
      // Swirl

      float l = length(shapeUV);
      float angle = 6. * atan2(shapeUV.y, shapeUV.x) + 4. * t;
      float twist = 1.2;
      float offset = 1. / pow(max(l, 1e-6), twist) + angle / TWO_PI;
      float mid = smoothstep(0., 1., pow(l, twist));
      shape = mix(0., fract(offset), mid);

    } else {
      // Sphere
      shapeUV *= 2.;

      float d = 1. - pow(length(shapeUV), 2.);
      float3 pos = float3(shapeUV, sqrt(max(0., d)));
      float3 lightPos = normalize(float3(cos(1.5 * t), .8, sin(1.25 * t)));
      shape = .5 + .5 * dot(lightPos, pos);
      shape *= step(0., d);
    }

    int type = int(floor(u.u_type));
    float dithering = 0.0;

    switch (type) {
      case 1: {
        dithering = step(hash21(ditheringNoiseUV), shape);
      } break;
      case 2:
      dithering = getBayerValue(pxSizeUV, 2);
      break;
      case 3:
      dithering = getBayerValue(pxSizeUV, 4);
      break;
      default :
      dithering = getBayerValue(pxSizeUV, 8);
      break;
    }

    dithering -= .5;
    float res = step(.5, shape + dithering);

    float3 fgColor = u.u_colorFront.rgb * u.u_colorFront.a;
    float fgOpacity = u.u_colorFront.a;
    float3 bgColor = u.u_colorBack.rgb * u.u_colorBack.a;
    float bgOpacity = u.u_colorBack.a;

    float3 color = fgColor * res;
    float opacity = fgOpacity * res;

    color += bgColor * (1. - opacity);
    opacity += bgOpacity * (1. - opacity);

    return float4(color, opacity);
  }

  """
}
