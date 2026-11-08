import Foundation
import MediaBridge

/// Commands run in linked libraries; iOS does not launch command-line processes.
final class MediaEngine: @unchecked Sendable {
    private let runner = UCFFmpegRunner()
    func cancel() { runner.cancel() }

    private func execute(_ args: [String], progress: @escaping @Sendable (Double, Double) -> Void = { _, _ in }) async throws -> String {
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                runner.ffmpeg(args, progress: progress) { code, text in
                    if code == 255 { continuation.resume(throwing: CompressorError.cancelled) }
                    else if code != 0 { continuation.resume(throwing: CompressorError.failed) }
                    else { continuation.resume(returning: text) }
                }
            }
        } onCancel: { self.cancel() }
    }

    func probe(_ url: URL) async throws -> MediaInfo {
        guard try Self.hasMP4Brand(url) else { throw CompressorError.mp4Only }
        let text: String = try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                runner.ffprobe(["-v", "error", "-protocol_whitelist", "file,pipe", "-show_format", "-show_streams", "-of", "json", url.path]) { code, output in
                    if code == 255 { continuation.resume(throwing: CompressorError.cancelled) }
                    else if code != 0 { continuation.resume(throwing: CompressorError.invalidMedia) }
                    else { continuation.resume(returning: output) }
                }
            }
        } onCancel: { self.cancel() }
        guard let data = text.data(using: .utf8),
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let streams = root["streams"] as? [[String: Any]],
              let video = streams.first(where: { ($0["codec_type"] as? String) == "video" && ((($0["disposition"] as? [String: Any])?["attached_pic"] as? Int) ?? 0) == 0 }) else { throw CompressorError.invalidMedia }
        let audio = streams.first { ($0["codec_type"] as? String) == "audio" }
        func number(_ value: Any?) -> Double { if let n = value as? NSNumber { return n.doubleValue }; return Double(value as? String ?? "") ?? 0 }
        func ratio(_ value: Any?, separator: Character, fallback: Double) -> Double {
            let parts = (value as? String ?? "").split(separator: separator).compactMap { Double($0) }
            guard parts.count == 2, parts[1] > 0, parts[0] > 0 else { return fallback }
            let result = parts[0] / parts[1]; return result.isFinite ? result : fallback
        }
        let format = root["format"] as? [String: Any]
        let duration = max(number(format?["duration"]), number(video["duration"]))
        let side = video["side_data_list"] as? [[String: Any]]
        let rotation = number(side?.first(where: { $0["rotation"] != nil })?["rotation"])
        let result = MediaInfo(duration: duration, width: Int(number(video["width"])), height: Int(number(video["height"])),
                               fps: ratio(video["avg_frame_rate"], separator: "/", fallback: 30), hasAudio: audio != nil,
                               audioBitrate: Int(number(audio?["bit_rate"])), channels: Int(number(audio?["channels"])),
                               sampleAspectRatio: ratio(video["sample_aspect_ratio"], separator: ":", fallback: 1), rotation: rotation)
        guard duration.isFinite, duration > 0, result.width > 0, result.height > 0 else { throw CompressorError.invalidMedia }
        return result
    }

    func compress(input: URL, output: URL, size: Int64, media: MediaInfo, options: CompressionOptions,
                  progress: @escaping @Sendable (Double, Int) -> Void) async throws -> Int64 {
        let plan = try CompressionPlan.make(size: size, media: media, options: options)
        var bitrate = plan.videoBitrate
        var succeeded = false
        defer { if !succeeded { try? FileManager.default.removeItem(at: output) } }
        for attempt in 1...4 {
            try Task.checkCancellation()
            try? FileManager.default.removeItem(at: output)
            progress(0, attempt)
            var args = ["-hide_banner", "-loglevel", "error", "-nostdin", "-noautorotate", "-protocol_whitelist", "file,pipe", "-i", input.path,
                        "-map", "0:v:0", "-map_metadata", "-1", "-map_chapters", "-1",
                        "-vf", "scale=\(plan.width):\(plan.height):flags=lanczos,setsar=1,fps=\(plan.fps),format=yuv420p",
                        "-c:v", "h264_videotoolbox", "-allow_sw", "1", "-b:v", String(bitrate), "-profile:v", "high", "-tag:v", "avc1"]
            if media.hasAudio {
                args += ["-map", "0:a:0", "-c:a", "aac", "-b:a", String(plan.audioBitrate), "-ac", String(plan.audioChannels), "-ar", String(plan.sampleRate)]
            } else { args += ["-an"] }
            args += ["-metadata:s:v:0", "rotate=\(media.rotation)", "-movflags", "+faststart", "-f", "mp4", "-y", output.path]
            _ = try await execute(args) { seconds, _ in progress(min(0.98, max(0, seconds / media.duration)), attempt) }
            try Task.checkCancellation()
            let actual = try Self.fileSize(output)
            if actual > 0, actual <= plan.targetBytes, actual < size {
                let final = try await probe(output)
                guard final.hasAudio == media.hasAudio,
                      abs(final.duration - media.duration) <= max(0.5, media.duration * 0.02) else { throw CompressorError.verification }
                succeeded = true; return actual
            }
            let excess = Double(actual - plan.targetBytes) * 8 / media.duration
            bitrate = Int(min(Double(bitrate) * 0.9, Double(bitrate) - excess * 1.15))
            guard bitrate >= max(16_000, plan.audioBitrate * 2) else { throw CompressorError.tinyTarget }
        }
        throw CompressorError.tinyTarget
    }

    static func fileSize(_ url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }

    static func hasMP4Brand(_ url: URL) throws -> Bool {
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        let bytes = [UInt8](try handle.read(upToCount: 1_048_576) ?? Data())
        func u32(_ offset: Int) -> UInt64 {
            bytes[offset..<(offset + 4)].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        }
        func text(_ offset: Int) -> String { String(bytes: bytes[offset..<(offset + 4)], encoding: .ascii) ?? "" }
        let brands: Set<String> = ["isom", "iso2", "iso3", "iso4", "iso5", "iso6", "mp41", "mp42", "avc1", "dash", "M4V ", "MSNV", "cmfc", "cmfs"]
        var offset = 0
        while offset + 8 <= bytes.count {
            var length = u32(offset); var header = 8
            if length == 1 {
                guard offset + 16 <= bytes.count else { return false }
                length = (u32(offset + 8) << 32) | u32(offset + 12); header = 16
            }
            guard length >= UInt64(header), length <= UInt64(bytes.count - offset) else { return false }
            if text(offset + 4) == "ftyp" {
                guard length >= UInt64(header + 8), length <= 65_536 else { return false }
                let major = text(offset + header)
                if ["qt  ", "M4A ", "M4B ", "avif", "avis", "heic", "heix", "mif1", "msf1"].contains(major) || major.hasPrefix("3g") { return false }
                if brands.contains(major) { return true }
                var index = offset + header + 8
                while index + 4 <= offset + Int(length) { if brands.contains(text(index)) { return true }; index += 4 }
                return false
            }
            offset += Int(length)
        }
        return false
    }
}
