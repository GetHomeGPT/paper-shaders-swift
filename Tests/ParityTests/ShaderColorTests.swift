import XCTest
@testable import PaperShaders

final class ShaderColorTests: XCTestCase {
  func testSixDigitHex() {
    let c = ShaderColor.parse("#e0eaff")
    XCTAssertEqual(c.x, 224 / 255, accuracy: 1e-6)
    XCTAssertEqual(c.y, 234 / 255, accuracy: 1e-6)
    XCTAssertEqual(c.z, 1, accuracy: 1e-6)
    XCTAssertEqual(c.w, 1)
  }

  func testThreeDigitHex() {
    XCTAssertEqual(ShaderColor.parse("#fff"), SIMD4(1, 1, 1, 1))
    let c = ShaderColor.parse("#f00")
    XCTAssertEqual(c, SIMD4(1, 0, 0, 1))
  }

  func testEightDigitHex() {
    let c = ShaderColor.parse("#ff000080")
    XCTAssertEqual(c.x, 1)
    XCTAssertEqual(c.w, 128 / 255, accuracy: 1e-6)
  }

  func testRgb() {
    XCTAssertEqual(ShaderColor.parse("rgb(255, 0, 0)"), SIMD4(1, 0, 0, 1))
    let c = ShaderColor.parse("rgba(0, 128, 255, 0.5)")
    XCTAssertEqual(c.y, 128 / 255, accuracy: 1e-6)
    XCTAssertEqual(c.w, 0.5, accuracy: 1e-6)
  }

  func testHslAchromatic() {
    let c = ShaderColor.parse("hsl(0, 0%, 50%)")
    XCTAssertEqual(c.x, 0.5, accuracy: 1e-6)
    XCTAssertEqual(c.y, 0.5, accuracy: 1e-6)
    XCTAssertEqual(c.z, 0.5, accuracy: 1e-6)
  }

  func testHslChromatic() {
    let c = ShaderColor.parse("hsl(120, 100%, 25%)")
    XCTAssertEqual(c.x, 0, accuracy: 1e-6)
    XCTAssertEqual(c.y, 0.5, accuracy: 1e-6)
    XCTAssertEqual(c.z, 0, accuracy: 1e-6)
  }

  func testUnsupportedFormatFallsBack() {
    XCTAssertEqual(ShaderColor.parse("papayawhip"), ShaderColor.fallback)
  }

  func testRgbPercentagesFallBackLikeUpstream() {
    // Upstream's rgb regex only matches integers; percentages yield [0,0,0,1].
    XCTAssertEqual(ShaderColor.parse("rgb(100%, 50%, 30%)"), SIMD4(0, 0, 0, 1))
  }
}
