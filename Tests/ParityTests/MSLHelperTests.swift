import Metal
import simd
import XCTest
@testable import PaperShaders

/// Validates that the GLSL-compat MSL helpers produce the same values as the
/// GLSL formulas (recomputed on the CPU with float precision).
final class MSLHelperTests: XCTestCase {
  private static let probeKernel = """

  kernel void helpers_probe(device float* out [[buffer(0)]],
                            uint id [[thread_position_in_grid]]) {
    if (id != 0) return;
    out[0] = glsl_mod(-3.5, 2.0);
    out[1] = glsl_mod(7.25, 2.5);
    float2 r = rotate(float2(1.0, 0.0), 1.5707964);
    out[2] = r.x;
    out[3] = r.y;
    out[4] = hash11(4.567);
    out[5] = hash21(float2(12.34, 56.78));
    float2 h22 = hash22(float2(3.21, 9.87));
    out[6] = h22.x;
    out[7] = h22.y;
    out[8] = snoise(float2(0.35, 0.71));
    out[9] = snoise(float2(-3.2, 7.9));
  }
  """

  func testHelpersMatchCPUReference() throws {
    guard let device = MTLCreateSystemDefaultDevice() else {
      throw XCTSkip("No Metal device available")
    }
    let library = try device.makeLibrary(source: MSL.common + Self.probeKernel, options: nil)
    let function = try XCTUnwrap(library.makeFunction(name: "helpers_probe"))
    let pipeline = try device.makeComputePipelineState(function: function)
    let buffer = try XCTUnwrap(device.makeBuffer(length: 10 * MemoryLayout<Float>.size))
    let queue = try XCTUnwrap(device.makeCommandQueue())
    let commands = try XCTUnwrap(queue.makeCommandBuffer())
    let encoder = try XCTUnwrap(commands.makeComputeCommandEncoder())
    encoder.setComputePipelineState(pipeline)
    encoder.setBuffer(buffer, offset: 0, index: 0)
    encoder.dispatchThreadgroups(
      MTLSize(width: 1, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
    )
    encoder.endEncoding()
    commands.commit()
    commands.waitUntilCompleted()

    let gpu = buffer.contents().bindMemory(to: Float.self, capacity: 10)

    XCTAssertEqual(gpu[0], 0.5, accuracy: 1e-6, "glsl_mod(-3.5, 2.0) — fmod would give -1.5")
    XCTAssertEqual(gpu[1], 2.25, accuracy: 1e-6)
    XCTAssertEqual(gpu[2], 0, accuracy: 1e-6)
    XCTAssertEqual(gpu[3], 1, accuracy: 1e-6)
    XCTAssertEqual(gpu[4], Self.hash11(4.567), accuracy: 1e-3)
    XCTAssertEqual(gpu[5], Self.hash21(SIMD2(12.34, 56.78)), accuracy: 1e-3)
    let h22 = Self.hash22(SIMD2(3.21, 9.87))
    XCTAssertEqual(gpu[6], h22.x, accuracy: 1e-3)
    XCTAssertEqual(gpu[7], h22.y, accuracy: 1e-3)
    XCTAssertEqual(gpu[8], Self.snoise(SIMD2(0.35, 0.71)), accuracy: 1e-3)
    XCTAssertEqual(gpu[9], Self.snoise(SIMD2(-3.2, 7.9)), accuracy: 1e-3)
  }

  // CPU ports of the GLSL formulas

  private static func fract(_ x: Float) -> Float { x - floor(x) }
  private static func fract(_ v: SIMD2<Float>) -> SIMD2<Float> { v - v.rounded(.down) }
  private static func fract(_ v: SIMD3<Float>) -> SIMD3<Float> { v - v.rounded(.down) }
  private static func glslMod(_ v: SIMD2<Float>, _ y: Float) -> SIMD2<Float> { v - y * (v / y).rounded(.down) }
  private static func glslMod(_ v: SIMD3<Float>, _ y: Float) -> SIMD3<Float> { v - y * (v / y).rounded(.down) }

  private static func hash11(_ p: Float) -> Float {
    var p = fract(p * 0.3183099) + 0.1
    p *= p + 19.19
    return fract(p * p)
  }

  private static func hash21(_ p: SIMD2<Float>) -> Float {
    var p = fract(p * SIMD2<Float>(0.3183099, 0.3678794)) + 0.1
    p += SIMD2(repeating: simd_dot(p, p + 19.19))
    return fract(p.x * p.y)
  }

  private static func hash22(_ p: SIMD2<Float>) -> SIMD2<Float> {
    var p = fract(p * SIMD2<Float>(0.3183099, 0.3678794)) + 0.1
    p += SIMD2(repeating: simd_dot(p, SIMD2(p.y, p.x) + 19.19))
    return fract(SIMD2(p.x * p.y, p.x + p.y))
  }

  private static func permute(_ x: SIMD3<Float>) -> SIMD3<Float> {
    glslMod(((x * 34.0) + 1.0) * x, 289.0)
  }

  private static func snoise(_ v: SIMD2<Float>) -> Float {
    let C = SIMD4<Float>(0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439)
    var i = (v + SIMD2(repeating: simd_dot(v, SIMD2(C.y, C.y)))).rounded(.down)
    let x0 = v - i + SIMD2(repeating: simd_dot(i, SIMD2(C.x, C.x)))
    let i1: SIMD2<Float> = (x0.x > x0.y) ? SIMD2(1, 0) : SIMD2(0, 1)
    var x12 = SIMD4<Float>(x0.x, x0.y, x0.x, x0.y) + SIMD4(C.x, C.x, C.z, C.z)
    x12.lowHalf -= i1
    i = glslMod(i, 289.0)
    let p = permute(
      permute(SIMD3(repeating: i.y) + SIMD3(0, i1.y, 1)) + SIMD3(repeating: i.x) + SIMD3(0, i1.x, 1)
    )
    let x12zw = SIMD2(x12.z, x12.w)
    var m = simd_max(
      0.5 - SIMD3<Float>(simd_dot(x0, x0), simd_dot(x12.lowHalf, x12.lowHalf), simd_dot(x12zw, x12zw)),
      SIMD3(repeating: 0)
    )
    m = m * m
    m = m * m
    let x = 2.0 * fract(p * C.w) - 1.0
    let h = abs(x) - 0.5
    let ox = (x + 0.5).rounded(.down)
    let a0 = x - ox
    m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h)
    var g = SIMD3<Float>()
    g.x = a0.x * x0.x + h.x * x0.y
    g.y = a0.y * x12.x + h.y * x12.y
    g.z = a0.z * x12.z + h.z * x12.w
    return 130.0 * simd_dot(m, g)
  }
}
