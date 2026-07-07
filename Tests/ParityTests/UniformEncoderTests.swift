import XCTest
@testable import PaperShaders

final class UniformEncoderTests: XCTestCase {
  func testSimplexNoiseLikeLayout() {
    // struct { float; float4 x[10]; float; float; float; } → 0, 16, 176, 180, 184
    let values: [UniformValue] = [
      .float(0.6),
      .float4Array([SIMD4(1, 2, 3, 4)], capacity: 10),
      .float(5),
      .float(2),
      .float(0),
    ]
    XCTAssertEqual(UniformEncoder.offsets(of: values), [0, 16, 176, 180, 184])
    let data = UniformEncoder.pack(values)
    XCTAssertEqual(data.count, 192)
    data.withUnsafeBytes { raw in
      XCTAssertEqual(raw.load(fromByteOffset: 0, as: Float.self), 0.6)
      XCTAssertEqual(raw.load(fromByteOffset: 16, as: Float.self), 1)
      XCTAssertEqual(raw.load(fromByteOffset: 28, as: Float.self), 4)
      // zero-filled beyond provided colors
      XCTAssertEqual(raw.load(fromByteOffset: 32, as: Float.self), 0)
      XCTAssertEqual(raw.load(fromByteOffset: 176, as: Float.self), 5)
      XCTAssertEqual(raw.load(fromByteOffset: 184, as: Float.self), 0)
    }
  }

  func testFloat2Alignment() {
    // struct { float; float2; float; } → 0, 8, 16
    let values: [UniformValue] = [.float(1), .float2(SIMD2(2, 3)), .float(4)]
    XCTAssertEqual(UniformEncoder.offsets(of: values), [0, 8, 16])
    let data = UniformEncoder.pack(values)
    data.withUnsafeBytes { raw in
      XCTAssertEqual(raw.load(fromByteOffset: 8, as: Float.self), 2)
      XCTAssertEqual(raw.load(fromByteOffset: 12, as: Float.self), 3)
      XCTAssertEqual(raw.load(fromByteOffset: 16, as: Float.self), 4)
    }
  }
}
