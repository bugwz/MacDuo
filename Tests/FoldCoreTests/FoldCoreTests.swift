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
    func testGlassProjectionPreservesHingeAndMonotonicContent() {
        for progress in stride(from: -1.0, through: 1.0, by: 0.1) {
            let pose = FoldPose(progress: progress)
            XCTAssertEqual(pose.sourceHeight(at: 0), 0)
            XCTAssertEqual(pose.width(at: 0), 1)
            var previous = -1.0
            for y in stride(from: 0.0, through: 1.0, by: 0.01) {
                let source = pose.sourceHeight(at: y)
                XCTAssertGreaterThan(source, previous)
                // Rays may cross the top border; the renderer fades those to black.
                XCTAssertTrue((0...1.1).contains(source))
                XCTAssertTrue((0.68...1.32).contains(pose.width(at: y)))
                previous = source
            }
        }
        let flat = FoldPose(progress: 0)
        XCTAssertEqual(flat.width(at: 0.75), 1)
        XCTAssertEqual(flat.sourceHeight(at: 0.75), 0.75)
        XCTAssertEqual(FoldPose(progress: 1).width(at: 0), 1)
        XCTAssertGreaterThan(FoldPose(progress: -1).width(at: 1), 1)
        XCTAssertLessThan(FoldPose(progress: 1).width(at: 1), 1)
        XCTAssertEqual(FoldPose(progress: 1).verticalScale, FoldPose(progress: -1).verticalScale)
        XCTAssertEqual(FoldPose(progress: 1).depthScale, -FoldPose(progress: -1).depthScale)
        XCTAssertEqual(FoldPose(progress: .nan).progress, 0)
        XCTAssertEqual(FoldPose(progress: .infinity).progress, 0)
        XCTAssertEqual(FoldPose(progress: 2).progress, 1)
    }

    func testRejectsMalformedSensorReports() {
        XCTAssertEqual(LidReport.angle(bytes: [1, 90, 0]), 90)
        XCTAssertNil(LidReport.angle(bytes: []))
        XCTAssertNil(LidReport.angle(bytes: [1, 90]))
        XCTAssertNil(LidReport.angle(bytes: [0, 90, 0]))
        XCTAssertNil(LidReport.angle(bytes: [1, 255, 255]))
    }
}
