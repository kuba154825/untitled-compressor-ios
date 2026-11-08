"""Export the private Mac handoff. Never replaces an existing export."""
from pathlib import Path
import hashlib
import json
import shutil
import zipfile

root = Path(__file__).resolve().parents[1]
base = Path.home() / "Downloads" / "Untitled Compressor iOS Source"
destination = base
index = 1
while destination.exists() or destination.with_suffix(".zip").exists():
    destination = base.with_name(f"{base.name} ({index})")
    index += 1
excluded = {".verification", ".build", "build", "DerivedData", "xcuserdata", ".swiftpm", "__pycache__"}
destination.mkdir(parents=True)
for source in root.rglob("*"):
    relative = source.relative_to(root)
    if any(part in excluded for part in relative.parts): continue
    if source.is_file():
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
archive = destination.with_suffix(".zip")
with zipfile.ZipFile(archive, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
    for file in sorted(destination.rglob("*")):
        if not file.is_file(): continue
        name = file.relative_to(destination).as_posix()
        info = zipfile.ZipInfo(name)
        info.create_system = 3
        info.external_attr = (0o100755 if file.suffix == ".sh" else 0o100644) << 16
        bundle.writestr(info, file.read_bytes(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
with zipfile.ZipFile(archive) as bundle:
    assert bundle.testzip() is None
    assert "UntitledCompressor.xcodeproj/project.pbxproj" in bundle.namelist()
    assert "Packages/MediaBridge/Package.swift" in bundle.namelist()
report = {"folder": str(destination), "archive": str(archive), "bytes": archive.stat().st_size, "sha256": hashlib.sha256(archive.read_bytes()).hexdigest(), "privateEditableSource": True, "xcodeCompiled": False}
(root / ".verification").mkdir(exist_ok=True)
(root / ".verification/export.json").write_text(json.dumps(report, indent=2))
print(json.dumps(report, indent=2))
