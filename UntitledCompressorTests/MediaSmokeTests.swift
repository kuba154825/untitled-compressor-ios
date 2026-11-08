import XCTest
import MediaBridge
@testable import UntitledCompressor

/// Run on an actual iPhone as well as the simulator before distributing an archive.
final class MediaSmokeTests: XCTestCase {
    private func command(_ args: [String]) async throws {
        let runner = UCFFmpegRunner()
        let code: Int32 = await withCheckedContinuation { continuation in
            runner.ffmpeg(args, progress: { _, _ in }) { result, _ in continuation.resume(returning: result) }
        }
        XCTAssertEqual(code, 0, "Fixture generation failed")
        if code != 0 { throw CompressorError.failed }
    }

    func testRealMP4BothModesAndAudio() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let input = folder.appendingPathComponent("żółć source.mp4")
        try await command(["-hide_banner", "-v", "error", "-f", "lavfi", "-i", "testsrc2=size=320x180:rate=24",
                           "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000", "-t", "6",
                           "-c:v", "mpeg4", "-q:v", "2", "-c:a", "aac", "-b:a", "128k", "-f", "mp4", "-y", input.path])
        let size = try MediaEngine.fileSize(input), media = try await MediaEngine().probe(input)
        XCTAssertTrue(media.hasAudio)
        for (index, options) in [CompressionOptions(), CompressionOptions(mode: .size, percent: 50, targetMB: Double(size) * 0.55 / 1_000_000)].enumerated() {
            let output = folder.appendingPathComponent("result\(index).mp4")
            let engine = MediaEngine()
            let result = try await engine.compress(input: input, output: output, size: size, media: media, options: options, progress: { _, _ in })
            let plan = try CompressionPlan.make(size: size, media: media, options: options)
            XCTAssertLessThanOrEqual(result, plan.targetBytes); XCTAssertGreaterThan(result, 0)
            let verified = try await engine.probe(output)
            XCTAssertTrue(verified.hasAudio); XCTAssertEqual(verified.duration, media.duration, accuracy: 0.3)
            try await command(["-v", "error", "-i", output.path, "-f", "null", "-"])
        }
        let silent = folder.appendingPathComponent("silent.mp4")
        try await command(["-v", "error", "-i", input.path, "-c:v", "copy", "-an", "-y", silent.path])
        let engine = MediaEngine(), silentMedia = try await engine.probe(silent)
        let output = folder.appendingPathComponent("silent-output.mp4")
        _ = try await engine.compress(input: silent, output: output, size: try MediaEngine.fileSize(silent), media: silentMedia, options: .init(), progress: { _, _ in })
        let final = try await engine.probe(output); XCTAssertFalse(final.hasAudio)
    }

    func testCancelBeforeLaunch() async {
        let runner = UCFFmpegRunner(); runner.cancel()
        let code: Int32 = await withCheckedContinuation { continuation in
            runner.ffmpeg(["-version"], progress: { _, _ in }) { result, _ in continuation.resume(returning: result) }
        }
        XCTAssertEqual(code, 255)
    }
}
