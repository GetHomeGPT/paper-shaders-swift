import simd

/// Port of upstream `paper-texture.frag`.
public enum PaperTexture {
  /// Descriptor.
  public static let descriptor = ShaderDescriptor(
    name: "paper-texture",
    fragmentSource: source,
    usesNoiseTexture: true,
    usesImageTexture: true
  )

  /// Parameters used to render this shader.
  public struct Params {
    /// Color front.
    public var colorFront: String
    /// Color back.
    public var colorBack: String
    /// Contrast.
    public var contrast: Float
    /// Roughness.
    public var roughness: Float
    /// Fiber.
    public var fiber: Float
    /// Fiber size.
    public var fiberSize: Float
    /// Crumples.
    public var crumples: Float
    /// Crumple size.
    public var crumpleSize: Float
    /// Folds.
    public var folds: Float
    /// Fold count.
    public var foldCount: Float
    /// Drops.
    public var drops: Float
    /// Seed.
    public var seed: Float
    /// Fade.
    public var fade: Float
    /// Sizing.
    public var sizing: ShaderSizingParams
    /// Speed.
    public var speed: Double
    /// Frame.
    public var frame: Double

    /// Creates an instance.
    public init(
      colorFront: String = "#9fadbc",
      colorBack: String = "#ffffff",
      contrast: Float = 0.3,
      roughness: Float = 0.4,
      fiber: Float = 0.3,
      fiberSize: Float = 0.2,
      crumples: Float = 0.3,
      crumpleSize: Float = 0.35,
      folds: Float = 0.65,
      foldCount: Float = 5,
      drops: Float = 0.2,
      seed: Float = 5.8,
      fade: Float = 0,
      sizing: ShaderSizingParams = ShaderSizingParams(fit: .cover, scale: 0.6),
      speed: Double = 0,
      frame: Double = 0
    ) {
      self.colorFront = colorFront
      self.colorBack = colorBack
      self.contrast = contrast
      self.roughness = roughness
      self.fiber = fiber
      self.fiberSize = fiberSize
      self.crumples = crumples
      self.crumpleSize = crumpleSize
      self.folds = folds
      self.foldCount = foldCount
      self.drops = drops
      self.seed = seed
      self.fade = fade
      self.sizing = sizing
      self.speed = speed
      self.frame = frame
    }

    /// Matches `PaperTextureUniforms` member order in the MSL source.
    public var uniforms: [UniformValue] {
      [
        .float4(ShaderColor.parse(colorFront)),
        .float4(ShaderColor.parse(colorBack)),
        .float(contrast),
        .float(roughness),
        .float(fiber),
        .float(fiberSize),
        .float(crumples),
        .float(crumpleSize),
        .float(folds),
        .float(foldCount),
        .float(drops),
        .float(seed),
        .float(fade),
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
      name: "Cardboard",
      params: Params(
        colorFront: "#c7b89e",
        colorBack: "#999180",
        contrast: 0.4,
        roughness: 0,
        fiber: 0.35,
        fiberSize: 0.14,
        crumples: 0.7,
        crumpleSize: 0.1,
        folds: 0,
        foldCount: 1,
        drops: 0.1,
        seed: 1.6
      )
    ),
    Preset(
      name: "Abstract",
      params: Params(
        colorFront: "#00eeff",
        colorBack: "#ff0a81",
        contrast: 0.85,
        roughness: 0,
        fiber: 0.1,
        fiberSize: 0.2,
        crumples: 0,
        crumpleSize: 0.3,
        folds: 1,
        foldCount: 3,
        drops: 0.2,
        seed: 2.2
      )
    ),
    Preset(
      name: "Details",
      params: Params(
        colorFront: "#00000000",
        colorBack: "#00000000",
        contrast: 0,
        roughness: 1,
        fiber: 0.27,
        fiberSize: 0.22,
        crumples: 1,
        crumpleSize: 0.5,
        folds: 1,
        foldCount: 15,
        drops: 0,
        seed: 6,
        sizing: ShaderSizingParams(fit: .cover, scale: 3)
      )
    ),
  ]

  static let source = """

  struct PaperTextureUniforms {
    float4 u_colorFront;
    float4 u_colorBack;
    float u_contrast;
    float u_roughness;
    float u_fiber;
    float u_fiberSize;
    float u_crumples;
    float u_crumpleSize;
    float u_folds;
    float u_foldCount;
    float u_drops;
    float u_seed;
    float u_fade;
  };

  static float ptGetUvFrame(float2 uv) {
    float aax = 2. * fwidth(uv.x);
    float aay = 2. * fwidth(uv.y);
    float left = smoothstep(0., aax, uv.x);
    float right = 1. - smoothstep(1. - aax, 1., uv.x);
    float bottom = smoothstep(0., aay, uv.y);
    float top = 1. - smoothstep(1. - aay, 1., uv.y);
    return left * right * bottom * top;
  }

  static float ptRandomR(float2 p, texture2d<float> noiseTex, sampler noiseSampler) {
    float2 uv = floor(p) / 100. + .5;
    return noiseTex.sample(noiseSampler, fract(uv)).r;
  }

  static float ptValueNoise(float2 st, texture2d<float> noiseTex, sampler noiseSampler) {
    float2 i = floor(st);
    float2 f = fract(st);
    float a = ptRandomR(i, noiseTex, noiseSampler);
    float b = ptRandomR(i + float2(1.0, 0.0), noiseTex, noiseSampler);
    float c = ptRandomR(i + float2(0.0, 1.0), noiseTex, noiseSampler);
    float d = ptRandomR(i + float2(1.0, 1.0), noiseTex, noiseSampler);
    float2 u = f * f * (3.0 - 2.0 * f);
    float x1 = mix(a, b, u.x);
    float x2 = mix(c, d, u.x);
    return mix(x1, x2, u.y);
  }

  static float ptFbm(float2 n, texture2d<float> noiseTex, sampler noiseSampler) {
    float total = 0.0;
    float amplitude = .4;
    for (int i = 0; i < 3; i++) {
      total += ptValueNoise(n, noiseTex, noiseSampler) * amplitude;
      n *= 1.99;
      amplitude *= 0.65;
    }
    return total;
  }

  static float ptRandomG(float2 p, texture2d<float> noiseTex, sampler noiseSampler) {
    float2 uv = floor(p) / 50. + .5;
    return noiseTex.sample(noiseSampler, fract(uv)).g;
  }

  static float ptRoughness(float2 p, texture2d<float> noiseTex, sampler noiseSampler) {
    p *= .1;
    float o = 0.;
    for (int i = 0; i < 3; i++) {
      float4 w = float4(floor(p), ceil(p));
      float2 f = fract(p);
      o += mix(
        mix(ptRandomG(w.xy, noiseTex, noiseSampler), ptRandomG(w.xw, noiseTex, noiseSampler), f.y),
        mix(ptRandomG(w.zy, noiseTex, noiseSampler), ptRandomG(w.zw, noiseTex, noiseSampler), f.y),
        f.x
      );
      o += .2 / exp(2. * abs(sin(.2 * p.x + .5 * p.y)));
      p *= 2.1;
    }
    return o / 3.;
  }

  static float ptFiberRandom(float2 p, texture2d<float> noiseTex, sampler noiseSampler) {
    float2 uv = floor(p) / 100.;
    return noiseTex.sample(noiseSampler, fract(uv)).b;
  }

  static float ptFiberValueNoise(float2 st, texture2d<float> noiseTex, sampler noiseSampler) {
    float2 i = floor(st);
    float2 f = fract(st);
    float a = ptFiberRandom(i, noiseTex, noiseSampler);
    float b = ptFiberRandom(i + float2(1.0, 0.0), noiseTex, noiseSampler);
    float c = ptFiberRandom(i + float2(0.0, 1.0), noiseTex, noiseSampler);
    float d = ptFiberRandom(i + float2(1.0, 1.0), noiseTex, noiseSampler);
    float2 u = f * f * (3.0 - 2.0 * f);
    float x1 = mix(a, b, u.x);
    float x2 = mix(c, d, u.x);
    return mix(x1, x2, u.y);
  }

  static float ptFiberNoiseFbm(float2 n, float2 seedOffset, texture2d<float> noiseTex, sampler noiseSampler) {
    float total = 0.0;
    float amplitude = 1.;
    for (int i = 0; i < 4; i++) {
      n = rotate(n, .7);
      total += ptFiberValueNoise(n + seedOffset, noiseTex, noiseSampler) * amplitude;
      n *= 2.;
      amplitude *= 0.6;
    }
    return total;
  }

  static float ptFiberNoise(float2 uv, float2 seedOffset, texture2d<float> noiseTex, sampler noiseSampler) {
    float epsilon = 0.001;
    float n1 = ptFiberNoiseFbm(uv + float2(epsilon, 0.0), seedOffset, noiseTex, noiseSampler);
    float n2 = ptFiberNoiseFbm(uv - float2(epsilon, 0.0), seedOffset, noiseTex, noiseSampler);
    float n3 = ptFiberNoiseFbm(uv + float2(0.0, epsilon), seedOffset, noiseTex, noiseSampler);
    float n4 = ptFiberNoiseFbm(uv - float2(0.0, epsilon), seedOffset, noiseTex, noiseSampler);
    return length(float2(n1 - n2, n3 - n4)) / (2.0 * epsilon);
  }

  static float2 ptRandomGB(float2 p, texture2d<float> noiseTex, sampler noiseSampler) {
    float2 uv = floor(p) / 50. + .5;
    return noiseTex.sample(noiseSampler, fract(uv)).gb;
  }

  static float ptCrumpledNoise(float2 t, float pw, texture2d<float> noiseTex, sampler noiseSampler) {
    float2 p = floor(t);
    float wsum = 0.;
    float cl = 0.;
    for (int y = -1; y < 2; y += 1) {
      for (int x = -1; x < 2; x += 1) {
        float2 b = float2(float(x), float(y));
        float2 q = b + p;
        float2 q2 = q - floor(q / 8.) * 8.;
        float2 c = q + ptRandomGB(q2, noiseTex, noiseSampler);
        float2 r = c - t;
        float w = pow(smoothstep(0., 1., 1. - abs(r.x)), pw) * pow(smoothstep(0., 1., 1. - abs(r.y)), pw);
        cl += (.5 + .5 * sin((q2.x + q2.y * 5.) * 8.)) * w;
        wsum += w;
      }
    }
    return pow(wsum != 0.0 ? cl / wsum : 0.0, .5) * 2.;
  }

  static float ptCrumplesShape(float2 uv, texture2d<float> noiseTex, sampler noiseSampler) {
    return ptCrumpledNoise(uv * .25, 16., noiseTex, noiseSampler) * ptCrumpledNoise(uv * .5, 2., noiseTex, noiseSampler);
  }

  static float2 ptFolds(float2 uv, constant PaperTextureUniforms& u,
                        texture2d<float> noiseTex, sampler noiseSampler) {
    float3 pp = float3(0.);
    float l = 9.;
    for (int index = 0; index < 15; index++) {
      float i = float(index);
      if (i >= u.u_foldCount) break;
      float2 rand = ptRandomGB(float2(i, i * u.u_seed), noiseTex, noiseSampler);
      float an = rand.x * TWO_PI;
      float2 p = float2(cos(an), sin(an)) * rand.y;
      float dist = distance(uv, p);
      l = min(l, dist);
      if (l == dist) {
        pp.xy = (uv - p.xy);
        pp.z = dist;
      }
    }
    return mix(pp.xy, float2(0.), pow(pp.z, .25));
  }

  static float ptDrops(float2 uv, constant PaperTextureUniforms& u,
                       texture2d<float> noiseTex, sampler noiseSampler) {
    float2 iDropsUV = floor(uv);
    float2 fDropsUV = fract(uv);
    float dropsMinDist = 1.;
    for (int j = -1; j <= 1; j++) {
      for (int i = -1; i <= 1; i++) {
        float2 neighbor = float2(float(i), float(j));
        float2 offset = ptRandomGB(iDropsUV + neighbor, noiseTex, noiseSampler);
        offset = .5 + .5 * sin(10. * u.u_seed + TWO_PI * offset);
        float2 pos = neighbor + offset - fDropsUV;
        float dist = length(pos);
        dropsMinDist = min(dropsMinDist, dropsMinDist * dist);
      }
    }
    return 1. - smoothstep(.05, .09, pow(dropsMinDist, .5));
  }

  fragment float4 ps_fragment(PSVertexOut in [[stage_in]],
                              constant PSGlobalUniforms& global [[buffer(0)]],
                              constant PaperTextureUniforms& u [[buffer(1)]],
                              constant PSSizingUniforms& sizing [[buffer(2)]],
                              texture2d<float> noiseTex [[texture(0)]],
                              sampler noiseSampler [[sampler(0)]],
                              texture2d<float> imageTex [[texture(1)]],
                              sampler imageSampler [[sampler(1)]]) {
    float2 imageUV = in.imageUV;
    float2 patternUV = in.imageUV - .5;
    patternUV = 5. * (patternUV * float2(sizing.u_imageAspectRatio, 1.));

    float2 fragCoordGL = float2(in.position.x, global.u_resolution.y - in.position.y);
    float2 roughnessUv = 1.5 * (fragCoordGL - .5 * global.u_resolution) / global.u_pixelRatio;
    float roughness = ptRoughness(roughnessUv + float2(1., 0.), noiseTex, noiseSampler) - ptRoughness(roughnessUv - float2(1., 0.), noiseTex, noiseSampler);

    float2 crumplesUV = fract(patternUV * .02 / u.u_crumpleSize - u.u_seed) * 32.;
    float crumples = u.u_crumples * (ptCrumplesShape(crumplesUV + float2(.05, 0.), noiseTex, noiseSampler) - ptCrumplesShape(crumplesUV, noiseTex, noiseSampler));

    float2 fiberUV = 2. / u.u_fiberSize * patternUV;
    float fiber = ptFiberNoise(fiberUV, float2(0.), noiseTex, noiseSampler);
    fiber = .5 * u.u_fiber * (fiber - 1.);

    float2 normal = float2(0.);
    float2 normalImage = float2(0.);

    float2 foldsUV = patternUV * .12;
    foldsUV = rotate(foldsUV, 4. * u.u_seed);
    float2 w = ptFolds(foldsUV, u, noiseTex, noiseSampler);
    foldsUV = rotate(foldsUV + .007 * cos(u.u_seed), .01 * sin(u.u_seed));
    float2 w2 = ptFolds(foldsUV, u, noiseTex, noiseSampler);

    float drops = u.u_drops * ptDrops(patternUV * 2., u, noiseTex, noiseSampler);

    float fade = u.u_fade * ptFbm(.17 * patternUV + 10. * u.u_seed, noiseTex, noiseSampler);
    fade = clamp(8. * fade * fade * fade, 0., 1.);

    w = mix(w, float2(0.), fade);
    w2 = mix(w2, float2(0.), fade);
    crumples = mix(crumples, 0., fade);
    drops = mix(drops, 0., fade);
    fiber *= mix(1., .5, fade);
    roughness *= mix(1., .5, fade);

    normal.xy += u.u_folds * min(5. * u.u_contrast, 1.) * 4. * max(float2(0.), w + w2);
    normalImage.xy += u.u_folds * 2. * w;
    normal.xy += crumples;
    normalImage.xy += 1.5 * crumples;
    normal.xy += 3. * drops;
    normalImage.xy += .2 * drops;
    normal.xy += u.u_roughness * 1.5 * roughness;
    normal.xy += fiber;
    normalImage += u.u_roughness * .75 * roughness;
    normalImage += .2 * fiber;

    float3 lightPos = float3(1., 2., 1.);
    float res = dot(normalize(float3(normal, 9.5 - 9. * pow(u.u_contrast, .1))), normalize(lightPos));

    float3 fgColor = u.u_colorFront.rgb * u.u_colorFront.a;
    float fgOpacity = u.u_colorFront.a;
    float3 bgColor = u.u_colorBack.rgb * u.u_colorBack.a;
    float bgOpacity = u.u_colorBack.a;

    imageUV += .02 * normalImage;
    float frame = ptGetUvFrame(imageUV);
    float4 image = imageTex.sample(imageSampler, imageUV);
    image.rgb += .6 * pow(u.u_contrast, .4) * (res - .7);
    frame *= image.a;

    float3 color = fgColor * res;
    float opacity = fgOpacity * res;
    color += bgColor * (1. - opacity);
    opacity += bgOpacity * (1. - opacity);
    opacity = mix(opacity, 1., frame);
    color -= .007 * drops;
    color.rgb = mix(color, image.rgb, frame);

    return float4(color, opacity);
  }

  """
}
