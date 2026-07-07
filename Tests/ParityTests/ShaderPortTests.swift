import Metal
import XCTest
@testable import PaperShaders

/// For each ported shader: the MSL compiles, the fragment uniforms struct
/// layout matches `UniformEncoder`, and a small frame renders.
final class ShaderPortTests: XCTestCase {
  private struct Case {
    let descriptor: ShaderDescriptor
    let uniforms: [UniformValue]
    let sizing: ShaderSizingParams
    let expectedMemberNames: [String]
  }

  /// One case per catalog entry, exercising the first (default) preset.
  private static let cases: [Case] = ShaderCatalog.all.map { entry in
    Case(
      descriptor: entry.descriptor,
      uniforms: entry.presets[0].uniforms,
      sizing: entry.presets[0].sizing,
      expectedMemberNames: entry.uniformMemberNames
    )
  }

  func testUniformLayoutsMatchMSLStructs() throws {
    guard let device = MTLCreateSystemDefaultDevice() else {
      throw XCTSkip("No Metal device available")
    }
    guard #available(macOS 13.0, iOS 16.0, *) else {
      throw XCTSkip("Pipeline reflection bindings API unavailable")
    }
    for testCase in Self.cases {
      let library = try device.makeLibrary(
        source: MSL.common + testCase.descriptor.fragmentSource,
        options: nil
      )
      let pipeline = MTLRenderPipelineDescriptor()
      pipeline.vertexFunction = library.makeFunction(name: "ps_vertex")
      pipeline.fragmentFunction = library.makeFunction(name: "ps_fragment")
      pipeline.colorAttachments[0].pixelFormat = .bgra8Unorm
      var reflection: MTLRenderPipelineReflection?
      _ = try device.makeRenderPipelineState(
        descriptor: pipeline,
        options: [.bufferTypeInfo],
        reflection: &reflection
      )
      let binding = reflection?.fragmentBindings.first { $0.index == 1 } as? MTLBufferBinding
      let members = try XCTUnwrap(
        binding?.bufferStructType?.members,
        "\(testCase.descriptor.name): fragment buffer(1) struct not found"
      ).sorted { $0.offset < $1.offset }
      XCTAssertEqual(members.map(\.name), testCase.expectedMemberNames, testCase.descriptor.name)
      XCTAssertEqual(
        members.map(\.offset),
        UniformEncoder.offsets(of: testCase.uniforms),
        testCase.descriptor.name
      )
    }
  }

  func testPortedShadersRender() throws {
    guard MTLCreateSystemDefaultDevice() != nil else {
      throw XCTSkip("No Metal device available")
    }
    for testCase in Self.cases {
      let renderer = try OffscreenRenderer(descriptor: testCase.descriptor)
      let texture = try renderer.render(
        width: 32,
        height: 32,
        frame: 41500,
        sizing: testCase.sizing,
        uniforms: testCase.uniforms
      )
      let rgba = OffscreenRenderer.rgbaBytes(of: texture)
      XCTAssertFalse(rgba.allSatisfy { $0 == 0 }, "\(testCase.descriptor.name): output is all zeros")
    }
  }
}
