import CoreGraphics
import ImageIO
import Metal
import XCTest
@testable import PaperShaders

final class OffscreenRendererTests: XCTestCase {
  /// Constant-color fragment; (0.2, 0.4, 0.8) maps exactly to (51, 102, 204).
  private static let constantShader = ShaderDescriptor(
    name: "constant",
    fragmentSource: """

    fragment float4 ps_fragment(PSVertexOut in [[stage_in]]) {
      return float4(0.2, 0.4, 0.8, 1.0);
    }
    """
  )

  func testConstantShaderRenderAndPNGRoundtrip() throws {
    guard MTLCreateSystemDefaultDevice() != nil else {
      throw XCTSkip("No Metal device available")
    }
    let renderer = try OffscreenRenderer(descriptor: Self.constantShader)
    let texture = try renderer.render(
      width: 64,
      height: 64,
      frame: 41500,
      sizing: .defaultPattern,
      uniforms: []
    )

    let rgba = OffscreenRenderer.rgbaBytes(of: texture)
    XCTAssertEqual(rgba.count, 64 * 64 * 4)
    // top-left and center pixels
    for offset in [0, (32 * 64 + 32) * 4] {
      XCTAssertEqual(rgba[offset], 51)
      XCTAssertEqual(rgba[offset + 1], 102)
      XCTAssertEqual(rgba[offset + 2], 204)
      XCTAssertEqual(rgba[offset + 3], 255)
    }

    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("paper-shaders-constant-\(UUID().uuidString).png")
    defer { try? FileManager.default.removeItem(at: url) }
    try OffscreenRenderer.writePNG(texture, to: url)

    let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
    let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
    XCTAssertEqual(image.width, 64)
    XCTAssertEqual(image.height, 64)
    let data = try XCTUnwrap(image.dataProvider?.data as Data?)
    let bytesPerPixel = image.bitsPerPixel / 8
    XCTAssertEqual(data[0], 51)
    XCTAssertEqual(data[1], 102)
    XCTAssertEqual(data[2], 204)
    XCTAssertGreaterThanOrEqual(bytesPerPixel, 3)
  }
}
