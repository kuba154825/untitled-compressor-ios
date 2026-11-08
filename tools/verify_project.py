"""Portable structural checks. Does not claim to compile Swift or replace Xcode."""
from pathlib import Path
import json
import plistlib
import re
import sys
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
text = (root / "UntitledCompressor.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
identifiers = re.findall(r'^\t\t"([A-F0-9]{24})" = \{', text, re.M)
assert len(identifiers) == len(set(identifiers)), "Duplicate project object ID"
declared = set(identifiers)
for value in re.findall(r'= ([A-F0-9]{24});', text):
    assert value in declared, f"Dangling project reference: {value}"
for relative in re.findall(r'"path" = "([^"]+)";', text):
    if relative.endswith((".app", ".xctest")): continue
    assert (root / relative).exists(), f"Missing project file: {relative}"
compiled = re.findall(r'"path" = "([^"]+\.swift)";', text)
actual = [str(p.relative_to(root)).replace("\\", "/") for folder in ["UntitledCompressor", "UntitledCompressorTests", "UntitledCompressorUITests"] for p in (root / folder).rglob("*.swift")]
assert sorted(compiled) == sorted(actual), "Swift source missing from project"
for name in ["Info.plist", "PrivacyInfo.xcprivacy"]:
    plistlib.loads((root / "UntitledCompressor" / name).read_bytes())
ET.parse(root / "UntitledCompressor.xcodeproj/xcshareddata/xcschemes/UntitledCompressor.xcscheme")
manifest = (root / "Packages/MediaBridge/Package.swift").read_text()
assert len(re.findall(r'\("\w+", "[a-f0-9]{64}"\)', manifest)) == 8
assert "8.1.2-min" in manifest and "full-gpl" not in manifest
ui = (root / "UntitledCompressor/UI/ContentView.swift").read_text()
assert "VIDEO FIRST" not in ui and "AUDIO SECOND" not in ui
assert "CompressionControls(options: $store.options" in ui
assert b"\r\n" not in (root / "build-mac.sh").read_bytes(), "Mac script has CRLF"

try:
    import tree_sitter
    import tree_sitter_swift
except ImportError:
    print("Optional Swift syntax parser unavailable; structural checks only")
else:
    parser = tree_sitter.Parser(tree_sitter.Language(tree_sitter_swift.language()))
    errors = []
    for path in [root / name for name in actual] + [root / "Packages/MediaBridge/Package.swift"]:
        tree = parser.parse(path.read_bytes())
        stack = [tree.root_node]
        while stack:
            node = stack.pop()
            if node.type == "ERROR" or node.is_missing: errors.append((str(path), node.start_point))
            stack.extend(node.children)
    assert not errors, errors
    print("Swift syntax parsing passed")
print(f"PASS: {len(actual)} Swift files, project references, shared scheme, plist files and 8 pinned frameworks")
