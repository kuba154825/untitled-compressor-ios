"""Validate a physical-device app and package it for signing in Sideloadly."""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import zipfile


def run(*args):
    return subprocess.check_output(args, text=True).strip()


def main():
    app = Path(sys.argv[1]).resolve()
    output = Path(sys.argv[2]).resolve()
    if sys.platform != "darwin":
        raise SystemExit("Validate and package on the macOS build runner.")
    info = plistlib.loads((app / "Info.plist").read_bytes())
    if info.get("CFBundleSupportedPlatforms") != ["iPhoneOS"]:
        raise SystemExit("Expected an iPhoneOS app, not a simulator or macOS build.")
    binary = app / info["CFBundleExecutable"]
    architectures = run("xcrun", "lipo", "-archs", str(binary)).split()
    if architectures != ["arm64"]:
        raise SystemExit(f"Unexpected device architectures: {architectures}")
    binaries = [binary]
    for framework in sorted((app / "Frameworks").glob("*.framework")):
        framework_info = plistlib.loads((framework / "Info.plist").read_bytes())
        binaries.append(framework / framework_info["CFBundleExecutable"])
    for executable in binaries:
        if not executable.is_file():
            raise SystemExit(f"Missing executable: {executable}")
        dependencies = run("otool", "-L", str(executable)).splitlines()[1:]
        for line in dependencies:
            dependency = line.strip().split(" (", 1)[0]
            if dependency.startswith("@rpath/"):
                relative = dependency[len("@rpath/"):]
                if not (app / "Frameworks" / relative).is_file():
                    raise SystemExit(f"Framework not embedded: {relative} (needed by {executable.name})")
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in sorted(app.rglob("*")):
            if path.is_file():
                archive.write(path, "Payload/" + app.name + "/" + path.relative_to(app).as_posix())
    with zipfile.ZipFile(output) as archive:
        invalid = archive.testzip()
        if invalid:
            raise SystemExit(f"Corrupt ZIP entry: {invalid}")
    digest = hashlib.sha256()
    with output.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    checksum = digest.hexdigest()
    (output.parent / "SHA256SUMS.txt").write_text(f"{checksum}  {output.name}\n")
    metadata = {
        "bundleIdentifier": info["CFBundleIdentifier"],
        "version": info["CFBundleShortVersionString"],
        "minimumIOS": info.get("MinimumOSVersion"),
        "platform": "iPhoneOS", "architectures": architectures,
        "frameworks": [str(p.relative_to(app)) for p in binaries[1:]],
        "signedForInstallation": False,
        "installation": "Sign and install using Sideloadly with your own Apple account.",
        "commit": os.environ.get("GITHUB_SHA"),
        "xcode": run("xcodebuild", "-version"),
        "sha256": checksum,
    }
    (output.parent / "BUILD-INFO.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(f"Validated and packaged: {output.name} ({output.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
