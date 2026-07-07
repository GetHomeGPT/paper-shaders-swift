/// MSL sources shared by every shader. Compiled at runtime with
/// `MTLDevice.makeLibrary(source:)` because `swift build` does not run the
/// Metal toolchain (equivalent of the upstream approach of embedding GLSL
/// in TypeScript files).
public enum MSL {
  /// GLSL-compat helpers + shared vertex shader.
  ///
  /// Direct port of upstream `shader-utils.ts` helpers and
  /// `vertex-shader.ts` (the 4 UV coordinate systems). GLSL `mod` is
  /// `glsl_mod` (Metal `fmod` truncates toward zero, GLSL mod does not).
  /// Fragment ports drop their local `#define PI` / `rotate` / hash / snoise
  /// copies in favor of these.
  public static let common = """
  #include <metal_stdlib>
  using namespace metal;

  #define TWO_PI 6.28318530718
  #define PI 3.14159265358979323846

  static inline float glsl_mod(float x, float y) { return x - y * floor(x / y); }
  static inline float2 glsl_mod(float2 x, float y) { return x - y * floor(x / y); }
  static inline float2 glsl_mod(float2 x, float2 y) { return x - y * floor(x / y); }
  static inline float3 glsl_mod(float3 x, float y) { return x - y * floor(x / y); }
  static inline float3 glsl_mod(float3 x, float3 y) { return x - y * floor(x / y); }

  static inline float2 rotate(float2 uv, float th) {
    return float2x2(float2(cos(th), sin(th)), float2(-sin(th), cos(th))) * uv;
  }

  static inline float hash11(float p) {
    p = fract(p * 0.3183099) + 0.1;
    p *= p + 19.19;
    return fract(p * p);
  }

  static inline float hash21(float2 p) {
    p = fract(p * float2(0.3183099, 0.3678794)) + 0.1;
    p += dot(p, p + 19.19);
    return fract(p.x * p.y);
  }

  static inline float2 hash22(float2 p) {
    p = fract(p * float2(0.3183099, 0.3678794)) + 0.1;
    p += dot(p, p.yx + 19.19);
    return fract(float2(p.x * p.y, p.x + p.y));
  }

  static inline float3 permute(float3 x) { return glsl_mod(((x * 34.0) + 1.0) * x, 289.0); }

  static inline float snoise(float2 v) {
    const float4 C = float4(0.211324865405187, 0.366025403784439,
      -0.577350269189626, 0.024390243902439);
    float2 i = floor(v + dot(v, C.yy));
    float2 x0 = v - i + dot(i, C.xx);
    float2 i1;
    i1 = (x0.x > x0.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);
    float4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;
    i = glsl_mod(i, 289.0);
    float3 p = permute(permute(i.y + float3(0.0, i1.y, 1.0))
      + i.x + float3(0.0, i1.x, 1.0));
    float3 m = max(0.5 - float3(dot(x0, x0), dot(x12.xy, x12.xy),
        dot(x12.zw, x12.zw)), 0.0);
    m = m * m;
    m = m * m;
    float3 x = 2.0 * fract(p * C.www) - 1.0;
    float3 h = abs(x) - 0.5;
    float3 ox = floor(x + 0.5);
    float3 a0 = x - ox;
    m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
    float3 g;
    g.x = a0.x * x0.x + h.x * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
  }

  struct PSGlobalUniforms {
    float2 u_resolution;
    float u_pixelRatio;
    float u_time;
  };

  struct PSSizingUniforms {
    float u_fit;
    float u_scale;
    float u_rotation;
    float u_originX;
    float u_originY;
    float u_offsetX;
    float u_offsetY;
    float u_worldWidth;
    float u_worldHeight;
    float u_imageAspectRatio;
  };

  struct PSVertexOut {
    float4 position [[position]];
    float2 objectUV;
    float2 objectBoxSize;
    float2 responsiveUV;
    float2 responsiveBoxGivenSize;
    float2 patternUV;
    float2 patternBoxSize;
    float2 imageUV;
  };

  static float3 ps_getBoxSize(float boxRatio, float2 givenBoxSize, float fit, float2 resolution) {
    float2 box = float2(0.0);
    // fit = none
    box.x = boxRatio * min(givenBoxSize.x / boxRatio, givenBoxSize.y);
    float noFitBoxWidth = box.x;
    if (fit == 1.0) { // fit = contain
      box.x = boxRatio * min(resolution.x / boxRatio, resolution.y);
    } else if (fit == 2.0) { // fit = cover
      box.x = boxRatio * max(resolution.x / boxRatio, resolution.y);
    }
    box.y = box.x / boxRatio;
    return float3(box, noFitBoxWidth);
  }

  vertex PSVertexOut ps_vertex(uint vertexID [[vertex_id]],
                               constant PSGlobalUniforms& global [[buffer(0)]],
                               constant PSSizingUniforms& sizing [[buffer(1)]]) {
    const float2 positions[4] = { float2(-1.0, -1.0), float2(1.0, -1.0), float2(-1.0, 1.0), float2(1.0, 1.0) };
    PSVertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);

    float2 uv = out.position.xy * 0.5;
    float2 boxOrigin = float2(0.5 - sizing.u_originX, sizing.u_originY - 0.5);
    float2 givenBoxSize = float2(sizing.u_worldWidth, sizing.u_worldHeight);
    givenBoxSize = max(givenBoxSize, float2(1.0)) * global.u_pixelRatio;
    float r = sizing.u_rotation * PI / 180.0;
    float2x2 graphicRotation = float2x2(float2(cos(r), sin(r)), float2(-sin(r), cos(r)));
    float2 graphicOffset = float2(-sizing.u_offsetX, sizing.u_offsetY);

    // ===================================================

    float fixedRatio = 1.0;
    float2 fixedRatioBoxGivenSize = float2(
    (sizing.u_worldWidth == 0.0) ? global.u_resolution.x : givenBoxSize.x,
    (sizing.u_worldHeight == 0.0) ? global.u_resolution.y : givenBoxSize.y
    );

    out.objectBoxSize = ps_getBoxSize(fixedRatio, fixedRatioBoxGivenSize, sizing.u_fit, global.u_resolution).xy;
    float2 objectWorldScale = global.u_resolution / out.objectBoxSize;

    float2 objectUV = uv;
    objectUV *= objectWorldScale;
    objectUV += boxOrigin * (objectWorldScale - 1.0);
    objectUV += graphicOffset;
    objectUV /= sizing.u_scale;
    objectUV = graphicRotation * objectUV;
    out.objectUV = objectUV;

    // ===================================================

    float2 responsiveBoxGivenSize = float2(
    (sizing.u_worldWidth == 0.0) ? global.u_resolution.x : givenBoxSize.x,
    (sizing.u_worldHeight == 0.0) ? global.u_resolution.y : givenBoxSize.y
    );
    out.responsiveBoxGivenSize = responsiveBoxGivenSize;
    float responsiveRatio = responsiveBoxGivenSize.x / responsiveBoxGivenSize.y;
    float2 responsiveBoxSize = ps_getBoxSize(responsiveRatio, responsiveBoxGivenSize, sizing.u_fit, global.u_resolution).xy;
    float2 responsiveBoxScale = global.u_resolution / responsiveBoxSize;

    float2 responsiveUV = uv;
    responsiveUV *= responsiveBoxScale;
    responsiveUV += boxOrigin * (responsiveBoxScale - 1.0);
    responsiveUV += graphicOffset;
    responsiveUV /= sizing.u_scale;
    responsiveUV.x *= responsiveRatio;
    responsiveUV = graphicRotation * responsiveUV;
    responsiveUV.x /= responsiveRatio;
    out.responsiveUV = responsiveUV;

    // ===================================================

    float2 patternBoxGivenSize = float2(
    (sizing.u_worldWidth == 0.0) ? global.u_resolution.x : givenBoxSize.x,
    (sizing.u_worldHeight == 0.0) ? global.u_resolution.y : givenBoxSize.y
    );
    float patternBoxRatio = patternBoxGivenSize.x / patternBoxGivenSize.y;

    float3 boxSizeData = ps_getBoxSize(patternBoxRatio, patternBoxGivenSize, sizing.u_fit, global.u_resolution);
    out.patternBoxSize = boxSizeData.xy;
    float patternBoxNoFitBoxWidth = boxSizeData.z;
    float2 patternBoxScale = global.u_resolution / boxSizeData.xy;

    float2 patternUV = uv;
    patternUV += graphicOffset / patternBoxScale;
    patternUV += boxOrigin;
    patternUV -= boxOrigin / patternBoxScale;
    patternUV *= global.u_resolution;
    patternUV /= global.u_pixelRatio;
    if (sizing.u_fit > 0.0) {
      patternUV *= (patternBoxNoFitBoxWidth / boxSizeData.x);
    }
    patternUV /= sizing.u_scale;
    patternUV = graphicRotation * patternUV;
    patternUV += boxOrigin / patternBoxScale;
    patternUV -= boxOrigin;
    // x100 is a default multiplier between vertex and fragment shaders
    // used upstream to avoid UV precision issues
    patternUV *= 0.01;
    out.patternUV = patternUV;

    // ===================================================

    float2 imageBoxSize;
    if (sizing.u_fit == 1.0) { // contain
      imageBoxSize.x = min(global.u_resolution.x / sizing.u_imageAspectRatio, global.u_resolution.y) * sizing.u_imageAspectRatio;
    } else if (sizing.u_fit == 2.0) { // cover
      imageBoxSize.x = max(global.u_resolution.x / sizing.u_imageAspectRatio, global.u_resolution.y) * sizing.u_imageAspectRatio;
    } else {
      imageBoxSize.x = min(10.0, 10.0 / sizing.u_imageAspectRatio * sizing.u_imageAspectRatio);
    }
    imageBoxSize.y = imageBoxSize.x / sizing.u_imageAspectRatio;
    float2 imageBoxScale = global.u_resolution / imageBoxSize;

    float2 imageUV = uv;
    imageUV *= imageBoxScale;
    imageUV += boxOrigin * (imageBoxScale - 1.0);
    imageUV += graphicOffset;
    imageUV /= sizing.u_scale;
    imageUV.x *= sizing.u_imageAspectRatio;
    imageUV = graphicRotation * imageUV;
    imageUV.x /= sizing.u_imageAspectRatio;

    imageUV += 0.5;
    imageUV.y = 1.0 - imageUV.y;
    out.imageUV = imageUV;

    return out;
  }

  """
}
