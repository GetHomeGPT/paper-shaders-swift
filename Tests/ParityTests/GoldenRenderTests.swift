import Metal
import XCTest
@testable import PaperShaders

/// Renders every ported preset with the golden capture settings
/// (512×512, frame=41500, speed=0, pixelRatio=1) into `PARITY_OUT`
/// (default `.build/parity-output`). `Scripts/check-parity.sh` then compares
/// the output against the workbench goldens with the upstream comparator.
final class GoldenRenderTests: XCTestCase {
  private static let frame: Double = 41500
  private static let size = 512

  func testRenderAllPresets() throws {
    guard MTLCreateSystemDefaultDevice() != nil else {
      throw XCTSkip("No Metal device available")
    }

    let outPath = ProcessInfo.processInfo.environment["PARITY_OUT"] ?? ".build/parity-output"
    let outURL = URL(fileURLWithPath: outPath, isDirectory: true)
    try FileManager.default.createDirectory(at: outURL, withIntermediateDirectories: true)

    var rendered: [String] = []
    for entry in ShaderCatalog.all {
      let renderer = try OffscreenRenderer(descriptor: entry.descriptor)
      for preset in entry.presets {
        let texture = try renderer.render(
          width: Self.size,
          height: Self.size,
          frame: Self.frame,
          pixelRatio: 1,
          sizing: preset.sizing,
          uniforms: preset.uniforms
        )
        let fileName = "\(entry.descriptor.name)--\(Self.slug(preset.name)).png"
        // Goldens include the white harness page behind non-opaque pixels.
        try OffscreenRenderer.writePNG(
          texture,
          to: outURL.appendingPathComponent(fileName),
          background: SIMD3(1, 1, 1)
        )
        rendered.append(fileName)
      }
    }

    XCTAssertEqual(rendered.count, ShaderCatalog.all.reduce(0) { $0 + $1.presets.count })
    XCTAssertEqual(rendered.count, Set(rendered).count, "preset slug collision")
  }

  /// Same slug rule as the workbench golden capture tool.
  private static func slug(_ name: String) -> String {
    var out = ""
    var lastWasDash = false
    for character in name.lowercased() {
      if character.isASCII && (character.isLetter || character.isNumber) {
        out.append(character)
        lastWasDash = false
      } else if !lastWasDash {
        out.append("-")
        lastWasDash = true
      }
    }
    return out.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
  }
}
