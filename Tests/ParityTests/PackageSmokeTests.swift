import XCTest
@testable import PaperShaders

final class PackageSmokeTests: XCTestCase {
  func testUpstreamCommitIsPinned() {
    XCTAssertEqual(Upstream.commit.count, 40)
  }
}
