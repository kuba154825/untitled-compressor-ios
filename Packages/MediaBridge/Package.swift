// swift-tools-version: 5.9
import PackageDescription

// Native FFmpeg/FFprobe, no Flutter dependency. Exact archives and SHA-256 values.
let base = "https://github.com/sk3llo/ffmpeg_kit_flutter/releases/download/8.1.2-min"
let libraries: [(String, String)] = [
    ("ffmpegkit", "3758f051a89f67442eeb17aa9f2e0aa3386a966338deb09dd2e6769aba4b7972"),
    ("libavcodec", "1e43d72539bbf0fc99fc74b451763dddcdd6aa0cc6ae7d5c9e144a31de2b6cfc"),
    ("libavdevice", "127f9e5290b8e5125a402c9c99482e731ed670c93ec0babf777e4af8274b703c"),
    ("libavfilter", "81ac35ca0961cfc41dd910963b00582e956c0c6ba8f0d49cd6d355ce9f9c840b"),
    ("libavformat", "2996af84ac2de0c782bc407e794ce51b14269b34f832c9b76554d1b31b8ec1d2"),
    ("libavutil", "a1ecbd41172995f3303f71b1486683e5cd47aeb28c58038873d11ec3fdbb6674"),
    ("libswresample", "f1465f88a72da4093ab1edb6cccd5e5d27ad7e00afb9227b2d290d85ed53814d"),
    ("libswscale", "da2802037839a59b6cba113dc923f4565de7d2fdf384f84d2a3503c2a299a363")
]
let package = Package(
    name: "MediaBridge", platforms: [.iOS(.v17)],
    products: [.library(name: "MediaBridge", targets: ["MediaBridge"])],
    targets: libraries.map { name, checksum in
        .binaryTarget(name: name, url: "\(base)/\(name).xcframework.zip", checksum: checksum)
    } + [
        .target(name: "MediaBridge", dependencies: libraries.map { .target(name: $0.0) },
                publicHeadersPath: "include",
                linkerSettings: [
                    .linkedFramework("AudioToolbox"), .linkedFramework("AVFoundation"),
                    .linkedFramework("CoreMedia"), .linkedFramework("CoreVideo"),
                    .linkedFramework("VideoToolbox"), .linkedFramework("Security"),
                    .linkedLibrary("z"), .linkedLibrary("bz2"), .linkedLibrary("iconv"), .linkedLibrary("c++")
                ])
    ]
)
