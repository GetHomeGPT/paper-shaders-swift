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

  /// A caller's image replaces the bundled sample: a solid-red image under the
  /// water shader leaves the center pixel red-dominant, the bundled flowers do
  /// not, and `nil` brings the flowers back.
  func testSetImageReplacesBundledSample() throws {
    guard MTLCreateSystemDefaultDevice() != nil else {
      throw XCTSkip("No Metal device available")
    }
    let renderer = try OffscreenRenderer(descriptor: Water.descriptor)
    let params = Water.Params(colorBack: "#000000", sizing: ShaderSizingParams(fit: .cover))
    func centerPixel() throws -> [UInt8] {
      let texture = try renderer.render(
        width: 32,
        height: 32,
        frame: 0,
        sizing: params.sizing,
        uniforms: params.uniforms
      )
      let rgba = OffscreenRenderer.rgbaBytes(of: texture)
      let offset = (16 * 32 + 16) * 4
      return Array(rgba[offset ..< offset + 4])
    }

    let bundled = try centerPixel()
    try renderer.setImage(Self.solidImage(red: 255, green: 0, blue: 0))
    let red = try centerPixel()
    XCTAssertGreaterThan(Int(red[0]), 200)
    XCTAssertLessThan(Int(red[1]), 40)
    XCTAssertLessThan(Int(red[2]), 40)
    XCTAssertNotEqual(red, bundled)

    try renderer.setImage(nil)
    XCTAssertEqual(try centerPixel(), bundled)
  }

  private static func solidImage(red: UInt8, green: UInt8, blue: UInt8) throws -> CGImage {
    let size = 4
    var bytes = [UInt8](repeating: 255, count: size * size * 4)
    for pixel in 0 ..< size * size {
      bytes[pixel * 4] = red
      bytes[pixel * 4 + 1] = green
      bytes[pixel * 4 + 2] = blue
    }
    let context = try XCTUnwrap(CGContext(
      data: &bytes,
      width: size,
      height: size,
      bitsPerComponent: 8,
      bytesPerRow: size * 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
    ))
    return try XCTUnwrap(context.makeImage())
  }
}
