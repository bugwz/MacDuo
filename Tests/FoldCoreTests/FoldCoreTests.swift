import XCTest
@testable import FoldCore

final class FoldCoreTests: XCTestCase {
    func testBidirectionalTravelAndLimits() {
        let mapping = FoldMapping(reference: 90, travel: 60)
        XCTAssertEqual(mapping.progress(angle: 90), 0)
        XCTAssertEqual(mapping.progress(angle: 89.5), 0)
        XCTAssertGreaterThan(mapping.progress(angle: 60), 0)
        XCTAssertLessThan(mapping.progress(angle: 120), 0)
        XCTAssertEqual(mapping.progress(angle: 30), 1)
        XCTAssertEqual(mapping.progress(angle: 150), -1)
        XCTAssertEqual(mapping.progress(angle: 0), 1)
        XCTAssertEqual(mapping.progress(angle: .nan), 0)
    }
    func testStoppingAndReversingIsDeterministic() {
        let mapping = FoldMapping()
        let outbound = [90.0, 80, 60].map { mapping.progress(angle: $0) }
        let inbound = [60.0, 80, 90].map { mapping.progress(angle: $0) }
        XCTAssertEqual(outbound, inbound.reversed())
        var latch = AngleLatch()
        XCTAssertEqual(latch.update(60), 60)
        XCTAssertEqual(latch.update(60.2), 60)
        XCTAssertEqual(latch.update(61), 61)
    }
    func testRejectsMalformedSensorReports() {
        XCTAssertEqual(LidReport.angle(bytes: [1, 90, 0]), 90)
        XCTAssertNil(LidReport.angle(bytes: []))
        XCTAssertNil(LidReport.angle(bytes: [1, 90]))
        XCTAssertNil(LidReport.angle(bytes: [0, 90, 0]))
        XCTAssertNil(LidReport.angle(bytes: [1, 255, 255]))
    }
}
