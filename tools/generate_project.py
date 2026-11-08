"""Generate the portable Xcode project; Python standard library only."""
from pathlib import Path
import hashlib
import json
import plistlib
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
objects = {}


def key(name):
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()


def add(symbol, isa, **fields):
    ident = key(symbol)
    objects[ident] = {"isa": isa, **fields}
    return ident


class Ref(str):
    pass


def ref(value):
    return Ref(value)


def encode(value, level=0):
    if isinstance(value, Ref):
        return str(value)
    if isinstance(value, dict):
        return "{\n" + "".join("\t" * (level + 1) + json.dumps(k) + " = " + encode(v, level + 1) + ";\n" for k, v in value.items()) + "\t" * level + "}"
    if isinstance(value, list):
        return "(\n" + "".join("\t" * (level + 1) + encode(v, level + 1) + ",\n" for v in value) + "\t" * level + ")"
    return json.dumps(str(value))


def configs(name, common, debug=None, release=None):
    ids = []
    for mode, extra in [("Debug", debug or {}), ("Release", release or {})]:
        ids.append(ref(add(name + mode, "XCBuildConfiguration", buildSettings={**common, **extra}, name=mode)))
    return ref(add(name + "configs", "XCConfigurationList", buildConfigurations=ids, defaultConfigurationIsVisible="0", defaultConfigurationName="Release"))


def file(name, filetype, path=None):
    return ref(add("file:" + name, "PBXFileReference", lastKnownFileType=filetype, path=path or name, sourceTree="<group>"))


def source_group(folder):
    children, builds = [], []
    for source in sorted((ROOT / folder).rglob("*.swift")):
        relative = source.relative_to(ROOT).as_posix()
        ident = file(relative, "sourcecode.swift", relative)
        children.append(ident)
        builds.append(ref(add("compile:" + relative, "PBXBuildFile", fileRef=ident)))
    return children, builds


app_files, app_builds = source_group("UntitledCompressor")
unit_files, unit_builds = source_group("UntitledCompressorTests")
ui_files, ui_builds = source_group("UntitledCompressorUITests")
assets = file("UntitledCompressor/Assets.xcassets", "folder.assetcatalog")
privacy = file("UntitledCompressor/PrivacyInfo.xcprivacy", "text.xml")
info = file("UntitledCompressor/Info.plist", "text.plist.xml")
notices = file("ThirdPartyNotices", "folder")
resources = [ref(add("resource:assets", "PBXBuildFile", fileRef=assets)), ref(add("resource:privacy", "PBXBuildFile", fileRef=privacy)), ref(add("resource:notices", "PBXBuildFile", fileRef=notices))]
product = ref(add("product:app", "PBXFileReference", explicitFileType="wrapper.application", path="Untitled Compressor.app", sourceTree="BUILT_PRODUCTS_DIR"))
unit_product = ref(add("product:unit", "PBXFileReference", explicitFileType="wrapper.cfbundle", path="UntitledCompressorTests.xctest", sourceTree="BUILT_PRODUCTS_DIR"))
ui_product = ref(add("product:ui", "PBXFileReference", explicitFileType="wrapper.cfbundle", path="UntitledCompressorUITests.xctest", sourceTree="BUILT_PRODUCTS_DIR"))
package = ref(add("package", "XCLocalSwiftPackageReference", relativePath="Packages/MediaBridge"))
package_product = ref(add("package:product", "XCSwiftPackageProductDependency", productName="MediaBridge"))
package_build = ref(add("package:build", "PBXBuildFile", productRef=package_product))
unit_package_build = ref(add("package:unitbuild", "PBXBuildFile", productRef=package_product))

project_settings = {
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0", "SDKROOT": "iphoneos", "SWIFT_VERSION": "5.0",
    "CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES", "CLANG_WARN_DOCUMENTATION_COMMENTS": "YES",
    "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER": "YES", "GCC_C_LANGUAGE_STANDARD": "gnu17",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES", "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
}
project_configs = configs("project", project_settings,
    {"SWIFT_OPTIMIZATION_LEVEL": "-Onone", "DEBUG_INFORMATION_FORMAT": "dwarf", "ENABLE_TESTABILITY": "YES", "ONLY_ACTIVE_ARCH": "YES", "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG"},
    {"SWIFT_OPTIMIZATION_LEVEL": "-O", "SWIFT_COMPILATION_MODE": "wholemodule", "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym", "ENABLE_NS_ASSERTIONS": "NO", "VALIDATE_PRODUCT": "YES"})
app_configs = configs("app", {
    "PRODUCT_BUNDLE_IDENTIFIER": "com.untitled.compressor", "PRODUCT_NAME": "Untitled Compressor",
    "PRODUCT_MODULE_NAME": "UntitledCompressor", "INFOPLIST_FILE": "UntitledCompressor/Info.plist",
    "CODE_SIGN_STYLE": "Automatic", "DEVELOPMENT_TEAM": "", "TARGETED_DEVICE_FAMILY": "1,2",
    "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator", "SUPPORTS_MACCATALYST": "NO",
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon", "CURRENT_PROJECT_VERSION": "1", "MARKETING_VERSION": "1.0.0",
    "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"],
    "SWIFT_EMIT_LOC_STRINGS": "NO", "SWIFT_STRICT_CONCURRENCY": "minimal",
}, release={"COPY_PHASE_STRIP": "YES", "STRIP_INSTALLED_PRODUCT": "YES", "SWIFT_REFLECTION_METADATA_LEVEL": "without-names"})
app_id = key("target:app")
unit_configs = configs("unit", {"PRODUCT_BUNDLE_IDENTIFIER": "com.untitled.compressor.tests", "PRODUCT_NAME": "$(TARGET_NAME)", "GENERATE_INFOPLIST_FILE": "YES", "CODE_SIGN_STYLE": "Automatic", "TARGETED_DEVICE_FAMILY": "1,2", "BUNDLE_LOADER": "$(TEST_HOST)", "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/Untitled Compressor.app/Untitled Compressor", "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks", "@loader_path/Frameworks"]})
ui_configs = configs("ui", {"PRODUCT_BUNDLE_IDENTIFIER": "com.untitled.compressor.uitests", "PRODUCT_NAME": "$(TARGET_NAME)", "GENERATE_INFOPLIST_FILE": "YES", "CODE_SIGN_STYLE": "Automatic", "TARGETED_DEVICE_FAMILY": "1,2", "TEST_TARGET_NAME": "UntitledCompressor"})


def phase(name, isa, files):
    return ref(add(name, isa, buildActionMask="2147483647", files=files, runOnlyForDeploymentPostprocessing="0"))


app = ref(add("target:app", "PBXNativeTarget", name="UntitledCompressor", productName="Untitled Compressor", productReference=product, productType="com.apple.product-type.application", buildConfigurationList=app_configs, buildPhases=[phase("app:sources", "PBXSourcesBuildPhase", app_builds), phase("app:frameworks", "PBXFrameworksBuildPhase", [package_build]), phase("app:resources", "PBXResourcesBuildPhase", resources)], buildRules=[], dependencies=[], packageProductDependencies=[package_product]))


def dependency(name):
    proxy = ref(add(name + ":proxy", "PBXContainerItemProxy", containerPortal=ref(key("project")), proxyType="1", remoteGlobalIDString=app, remoteInfo="UntitledCompressor"))
    return ref(add(name + ":dependency", "PBXTargetDependency", target=app, targetProxy=proxy))


unit = ref(add("target:unit", "PBXNativeTarget", name="UntitledCompressorTests", productName="UntitledCompressorTests", productReference=unit_product, productType="com.apple.product-type.bundle.unit-test", buildConfigurationList=unit_configs, buildPhases=[phase("unit:sources", "PBXSourcesBuildPhase", unit_builds), phase("unit:frameworks", "PBXFrameworksBuildPhase", [unit_package_build]), phase("unit:resources", "PBXResourcesBuildPhase", [])], buildRules=[], dependencies=[dependency("unit")], packageProductDependencies=[package_product]))
ui = ref(add("target:ui", "PBXNativeTarget", name="UntitledCompressorUITests", productName="UntitledCompressorUITests", productReference=ui_product, productType="com.apple.product-type.bundle.ui-testing", buildConfigurationList=ui_configs, buildPhases=[phase("ui:sources", "PBXSourcesBuildPhase", ui_builds), phase("ui:frameworks", "PBXFrameworksBuildPhase", []), phase("ui:resources", "PBXResourcesBuildPhase", [])], buildRules=[], dependencies=[dependency("ui")]))
products = ref(add("products", "PBXGroup", children=[product, unit_product, ui_product], name="Products", sourceTree="<group>"))
group = ref(add("mainGroup", "PBXGroup", children=app_files + [assets, privacy, info, notices] + unit_files + ui_files + [products], sourceTree="<group>"))
project = ref(add("project", "PBXProject", attributes={"LastUpgradeCheck": "1600", "TargetAttributes": {app_id: {"CreatedOnToolsVersion": "16.0"}, str(unit): {"TestTargetID": app}, str(ui): {"TestTargetID": app}}}, buildConfigurationList=project_configs, compatibilityVersion="Xcode 15.0", developmentRegion="en", hasScannedForEncodings="0", knownRegions=["en", "pl", "Base"], mainGroup=group, productRefGroup=products, projectDirPath="", projectRoot="", targets=[app, unit, ui], packageReferences=[package]))
project_dir = ROOT / "UntitledCompressor.xcodeproj"
project_dir.mkdir(exist_ok=True)
(project_dir / "project.pbxproj").write_text("// !$*UTF8*$!\n" + encode({"archiveVersion": "1", "classes": {}, "objectVersion": "60", "objects": objects, "rootObject": project}) + "\n", encoding="utf-8")
workspace = project_dir / "project.xcworkspace"
workspace.mkdir(exist_ok=True)
(workspace / "contents.xcworkspacedata").write_text('<?xml version="1.0" encoding="UTF-8"?><Workspace version="1.0"><FileRef location="self:"></FileRef></Workspace>\n')
scheme = ET.Element("Scheme", LastUpgradeVersion="1600", version="1.3")


def buildable(parent, target, name, binary):
    ET.SubElement(parent, "BuildableReference", BuildableIdentifier="primary", BlueprintIdentifier=str(target), BuildableName=binary, BlueprintName=name, ReferencedContainer="container:UntitledCompressor.xcodeproj")


action = ET.SubElement(scheme, "BuildAction", parallelizeBuildables="YES", buildImplicitDependencies="YES")
entries = ET.SubElement(action, "BuildActionEntries")
entry = ET.SubElement(entries, "BuildActionEntry", buildForTesting="YES", buildForRunning="YES", buildForProfiling="YES", buildForArchiving="YES", buildForAnalyzing="YES")
buildable(entry, app, "UntitledCompressor", "Untitled Compressor.app")
test_action = ET.SubElement(scheme, "TestAction", buildConfiguration="Debug", selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB", selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB", shouldUseLaunchSchemeArgsEnv="YES")
testables = ET.SubElement(test_action, "Testables")
for target, name in [(unit, "UntitledCompressorTests"), (ui, "UntitledCompressorUITests")]:
    testable = ET.SubElement(testables, "TestableReference", skipped="NO", parallelizable="NO")
    buildable(testable, target, name, name + ".xctest")
launch = ET.SubElement(scheme, "LaunchAction", buildConfiguration="Debug", selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB", selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB", launchStyle="0", useCustomWorkingDirectory="NO", ignoresPersistentStateOnLaunch="NO", debugDocumentVersioning="YES", allowLocationSimulation="YES")
buildable(ET.SubElement(launch, "BuildableProductRunnable", runnableDebuggingMode="0"), app, "UntitledCompressor", "Untitled Compressor.app")
profile = ET.SubElement(scheme, "ProfileAction", buildConfiguration="Release", shouldUseLaunchSchemeArgsEnv="YES", savedToolIdentifier="", useCustomWorkingDirectory="NO", debugDocumentVersioning="YES")
buildable(ET.SubElement(profile, "BuildableProductRunnable", runnableDebuggingMode="0"), app, "UntitledCompressor", "Untitled Compressor.app")
ET.SubElement(scheme, "AnalyzeAction", buildConfiguration="Debug")
ET.SubElement(scheme, "ArchiveAction", buildConfiguration="Release", revealArchiveInOrganizer="YES")
schemes = project_dir / "xcshareddata/xcschemes"; schemes.mkdir(parents=True, exist_ok=True)
ET.indent(scheme)
ET.ElementTree(scheme).write(schemes / "UntitledCompressor.xcscheme", encoding="utf-8", xml_declaration=True)

# Validate object references before writing the transfer bundle.
def references(value):
    if isinstance(value, Ref):
        assert str(value) in objects, value
    elif isinstance(value, dict):
        for item in value.values(): references(item)
    elif isinstance(value, list):
        for item in value: references(item)


references(objects)
for name in ["Info.plist", "PrivacyInfo.xcprivacy"]:
    plistlib.loads((ROOT / "UntitledCompressor" / name).read_bytes())
print(f"Generated {project_dir.name}: {len(objects)} objects, app + unit/media + UI tests")
