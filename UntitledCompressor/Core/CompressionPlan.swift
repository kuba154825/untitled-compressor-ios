import Foundation

enum CompressionMode: String, Codable, CaseIterable {
    case percent, size
}

struct CompressionOptions: Codable, Equatable {
    var mode: CompressionMode = .percent
    var percent: Double = 50
    var targetMB: Double = 10
}

struct MediaInfo: Codable, Equatable {
    var duration: Double
    var width: Int
    var height: Int
    var fps: Double
    var hasAudio: Bool
    var audioBitrate: Int
    var channels: Int
    var sampleAspectRatio: Double = 1
    var rotation: Double = 0
}

enum CompressorError: Error, LocalizedError {
    case mp4Only, invalidMedia, smallerTarget, tinyTarget, invalidNumber, failed, verification, cancelled
    var errorDescription: String? {
        switch self {
        case .mp4Only: return "Only MP4 videos are supported."
        case .invalidMedia: return "This video could not be read."
        case .smallerTarget: return "Choose a target smaller than the original file."
        case .tinyTarget: return "This target is too small. Increase the output size."
        case .invalidNumber: return "Enter a valid output size."
        case .failed: return "Compression failed. Try a larger output size."
        case .verification: return "The compressed video could not be verified."
        case .cancelled: return "Cancelled"
        }
    }
}

struct CompressionPlan: Equatable {
    let targetBytes: Int64
    let videoBitrate: Int
    let audioBitrate: Int
    let audioChannels: Int
    let sampleRate: Int
    let width: Int
    let height: Int
    let fps: Double

    static func make(size: Int64, media m: MediaInfo, options o: CompressionOptions) throws -> Self {
        guard m.duration.isFinite, m.duration > 0, m.width > 0, m.height > 0,
              m.fps.isFinite, m.fps > 0, m.sampleAspectRatio.isFinite,
              m.sampleAspectRatio > 0 else { throw CompressorError.invalidMedia }
        guard o.percent.isFinite, (1...99).contains(o.percent), o.targetMB.isFinite,
              (0.01...1_000_000).contains(o.targetMB) else { throw CompressorError.invalidNumber }
        let bytes = o.mode == .size ? o.targetMB * 1_000_000 : Double(size) * (1 - o.percent / 100)
        guard bytes >= 1, bytes < Double(size), bytes < Double(Int64.max) else { throw CompressorError.smallerTarget }
        let target = Int64(bytes.rounded(.down))
        let overhead = max(4096, max(ceil(m.duration * (m.fps * 12 + (m.hasAudio ? 230 : 0))), ceil(bytes * 0.012)))
        let totalDouble = floor((Double(target) - overhead) * 8 / m.duration)
        guard totalDouble.isFinite, totalDouble >= (m.hasAudio ? 48_000 : 16_000),
              totalDouble < Double(Int.max) else { throw CompressorError.tinyTarget }
        let total = Int(totalDouble)
        var audio = 0
        if m.hasAudio {
            let desired = total >= 1_500_000 ? 128_000 : total >= 650_000 ? 96_000 : total >= 300_000 ? 64_000 : total >= 180_000 ? 48_000 : total >= 100_000 ? 32_000 : total >= 65_000 ? 24_000 : 16_000
            audio = max(16_000, min(desired, min(total / 3, m.audioBitrate > 0 ? max(16_000, m.audioBitrate) : desired)))
        }
        let video = total - audio
        let fps = min(m.fps, video < 70_000 ? 12 : video < 150_000 ? 18 : m.fps)
        let scale = min(1, sqrt(Double(video) / max(1, Double(m.width) * m.sampleAspectRatio * Double(m.height) * fps * 0.065)))
        func even(_ x: Double) -> Int { max(2, Int(floor(x / 2)) * 2) }
        return Self(targetBytes: target, videoBitrate: video, audioBitrate: audio,
                    audioChannels: audio < 64_000 ? 1 : min(2, max(1, m.channels)),
                    sampleRate: audio < 24_000 ? 16_000 : audio < 48_000 ? 24_000 : 48_000,
                    width: even(Double(m.width) * m.sampleAspectRatio * scale),
                    height: even(Double(m.height) * scale), fps: fps)
    }
}
