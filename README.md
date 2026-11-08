# Untitled Compressor for iOS

Native SwiftUI source for iPhone and iPad, iOS 17 or newer. No Node.js, Electron, Flutter, CocoaPods or Homebrew is needed.

## Build from Windows without a Mac

See **WINDOWS-BUILD.md**. The manual GitHub Actions workflow builds an unsigned
physical-iPhone IPA using a standard macOS runner. The first Release build
succeeded with Xcode 16.4 on November 8, 2026:
https://github.com/kuba154825/untitled-compressor-ios/actions/runs/42525718155

Download the IPA artifact, then sign and install it using Sideloadly on Windows
with your own Apple account. The free signing route needs refreshing every
seven days. The source repository is public with the owner's approval so its
standard macOS Actions runner can be used for free.

The IPA has been compiled and its packaging checked, but has not been run on
an iPhone or in the simulator. Test actual compression on your device.

## On your friend's Mac

1. Unzip the complete source folder, keeping `Packages/MediaBridge` beside the Xcode project.
2. Open `UntitledCompressor.xcodeproj`. Allow Xcode to resolve the local MediaBridge package and download its eight pinned FFmpeg XCFrameworks. The archives total about 40 MB; Xcode validates their SHA-256 checksums.
3. Select the **UntitledCompressor** scheme and an installed iPhone simulator. Press **Run**. A simulator build does not need a signing team.
4. For a real iPhone: select the app target → **Signing & Capabilities**, choose your Apple development team, and change `com.untitled.compressor` to a unique bundle identifier you control. Connect the iPhone, select it as the destination, and Run. Finish any device trust/developer-mode setup yourself.
5. Before distribution, run **Product → Test** on the simulator and a physical iPhone. For a signed release use **Product → Archive** with a device destination, then Xcode Organizer. The source ZIP is a development handoff, not an installable IPA.

You can also compile an unsigned simulator build from Terminal on the Mac:

```bash
bash build-mac.sh
```

To run the included tests, use the name of an installed simulator from Xcode's destination list:

```bash
IOS_DESTINATION="platform=iOS Simulator,name=iPhone 16" bash build-mac.sh test
```

If that simulator is not installed, choose an available one. You can build directly with:

```bash
xcodebuild -project UntitledCompressor.xcodeproj -scheme UntitledCompressor \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## App behavior

- Import multiple **MP4 videos from Files**, including iCloud files once downloaded. MOV, audio-only MP4, corrupt data, and renamed non-MP4 containers are rejected. To use a Photos video, save/export it as MP4 in Files first; renaming MOV to MP4 does not convert it.
- **Compression %** means percentage removed: 50% leaves at most half the original byte size. **Target MB** is a maximum per video, using decimal MB. Controls work before adding a file. Global controls apply to queued jobs; each queued file also has its own settings.
- Files stay on the device. Originals are copied into the app sandbox and never overwritten. Completed videos and the queue survive relaunch. Remove/Clear deletes only the app's copies; save important results first.
- Compress sequentially, cancel, retry with a different target, preview, then use **Share / Save → Save to Files**, AirDrop or another share destination. ENG/PL and appearance settings persist.
- Keep the app foregrounded for long jobs. iOS permits only a limited background finishing period; the app cancels safely if that expires. It does not claim unlimited background processing.

## Engine and private implementation notes

FFmpeg and FFprobe are linked native libraries, not subprocesses or downloaded executable tools. `Packages/MediaBridge/Package.swift` declares eight checksum-pinned archives from the **8.1.2-min** release of [sk3llo/ffmpeg_kit_flutter](https://github.com/sk3llo/ffmpeg_kit_flutter/releases/tag/8.1.2-min). Only the native frameworks are used; there is no Flutter dependency. The checked archives contain iOS arm64 and arm64/x86_64 simulator slices. The bridge uses the actual FFmpegKit headers for async execution, per-session progress, completion and cancellation.

The planner follows the Windows version's target semantics and reserves MP4 overhead. Video receives at least two thirds of the planned media bitrate, usually more. Audio is retained, with progressively lower AAC bitrates at small targets. Targets too small to maintain that priority and audio are rejected. Bitrate allocation is a heuristic, not a perceptual guarantee for every scene or soundtrack.

The iOS path uses `h264_videotoolbox`, with software fallback allowed where supported by VideoToolbox. It uses measured-size retries rather than Windows/libx264 two-pass encoding. Each result must be smaller than the source and no larger than the chosen limit, with the expected duration and audio presence verified through FFprobe. Up to four attempts are allowed; it never cuts a file short to fake the size. Severe compression can lose fine detail or intelligibility. Some simulator/device combinations may reject very low bitrates; test those limits on the intended iPhone.

Output is MP4 H.264 8-bit 4:2:0 + AAC. Only the first ordinary video and first audio stream are retained. Extra tracks, subtitles, chapters and source metadata are omitted. The code preserves rotation and accounts for sample aspect ratio. HDR/Dolby Vision tone mapping is not implemented or validated; use SDR MP4 for the first release. Export speed, heat, large files, variable frame rate and extreme targets need physical-device testing.

The `min` package avoids bundling the GPL x264 codec used by the Windows build. The third-party libraries still have their own licenses; copies and provenance are in `ThirdPartyNotices`. Review those obligations before public distribution. Do not replace the package with a GPL variant without reviewing that change.

Swift and Objective-C application code compile to native machine code; there is no app JavaScript, JS obfuscator or V8 bytecode. Release settings enable optimization and stripping. Native binaries can still be reverse engineered. This source is now public with the owner's approval; the downloadable IPA artifact does not include dSYM/debug artifacts.

## Verification status

The physical-device Release app was successfully compiled with Xcode 16.4 on
GitHub's macOS runner on November 8, 2026. The build checked the project
structure, arm64 architecture, embedded dynamic framework dependencies, and
IPA ZIP integrity. The downloaded artifact's SHA-256 was checked locally.
The app remains unsigned and has not been run on an iPhone or simulator.

The included runtime tests have not been run in this build:

- `CompressionTests`: target arithmetic, video/audio budget priority, silent input, invalid values and container detection.
- `MediaSmokeTests`: generate real test videos; compress percentage and target-MB outputs; verify size, duration, audio and full decoding; verify silent output and cancellation before launch.
- `ControlsTests`: operate the size controls with an empty queue and switch languages.

`tools/generate_project.py` regenerates the Xcode project without third-party project generators. `tools/verify_project.py` checks its portable structure with Python 3. Optional syntax checks use `tree-sitter` and `tree-sitter-swift`; they are not substitutes for Xcode compilation.

## Source layout

```text
UntitledCompressor.xcodeproj/  ready-to-open shared Xcode scheme
UntitledCompressor/           app, SwiftUI screens, queue, planner, media engine
Packages/MediaBridge/         Objective-C bridge and pinned native dependencies
UntitledCompressorTests/      planner and real-media tests
UntitledCompressorUITests/    controls regression test
ThirdPartyNotices/            dependency licenses and provenance
build-mac.sh                 Mac simulator build/test helper
tools/                       portable project generator and verification
```
