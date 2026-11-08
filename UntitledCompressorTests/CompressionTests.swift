import XCTest
@testable import UntitledCompressor

final class CompressionTests: XCTestCase {
    private let media = MediaInfo(duration: 6, width: 480, height: 270, fps: 24, hasAudio: true, audioBitrate: 192_000, channels: 2)
    func testPercentageMeansReduction() throws {
        let plan = try CompressionPlan.make(size: 939_318, media: media, options: .init(mode: .percent, percent: 50, targetMB: 10))
        XCTAssertEqual(plan.targetBytes, 469_659)
        XCTAssertGreaterThanOrEqual(plan.videoBitrate, plan.audioBitrate * 2)
        XCTAssertEqual(plan.width % 2, 0); XCTAssertEqual(plan.height % 2, 0)
    }
    func testDecimalMB() throws {
        let plan = try CompressionPlan.make(size: 939_318, media: media, options: .init(mode: .size, percent: 50, targetMB: 0.15))
        XCTAssertEqual(plan.targetBytes, 150_000)
        XCTAssertGreaterThanOrEqual(plan.videoBitrate, plan.audioBitrate * 2)
    }
    func testAggressiveTargetsKeepVideoPriority() throws {
        for percent in [25.0, 50, 75, 90, 95] {
            let plan = try CompressionPlan.make(size: 939_318, media: media, options: .init(mode: .percent, percent: percent, targetMB: 10))
            XCTAssertGreaterThanOrEqual(plan.videoBitrate, plan.audioBitrate * 2)
            XCTAssertGreaterThanOrEqual(plan.audioBitrate, 16_000)
            XCTAssertLessThanOrEqual(plan.width, media.width); XCTAssertLessThanOrEqual(plan.height, media.height)
        }
    }
    func testSilentSourceDoesNotInventAudio() throws {
        var silent = media; silent.hasAudio = false
        XCTAssertEqual(try CompressionPlan.make(size: 939_318, media: silent, options: .init()).audioBitrate, 0)
    }
    func testInvalidAndImpossibleTargets() {
        for mb in [Double.nan, .infinity, 0, 0.01, 1] {
            XCTAssertThrowsError(try CompressionPlan.make(size: 939_318, media: media, options: .init(mode: .size, percent: 50, targetMB: mb)))
        }
        var invalid = media; invalid.duration = 0
        XCTAssertThrowsError(try CompressionPlan.make(size: 939_318, media: invalid, options: .init()))
    }
    func testCorruptAndRenamedFilesAreRejected() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        defer { try? FileManager.default.removeItem(at: file) }
        try Data("not mp4".utf8).write(to: file)
        XCTAssertFalse(try MediaEngine.hasMP4Brand(file))
        var mov = Data([0, 0, 0, 20]); mov.append(Data("ftypqt  ".utf8)); mov.append(Data([0, 0, 0, 0])); mov.append(Data("isom".utf8))
        try mov.write(to: file); XCTAssertFalse(try MediaEngine.hasMP4Brand(file))
    }
}
