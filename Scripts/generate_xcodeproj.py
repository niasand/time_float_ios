#!/usr/bin/env python3
"""Write TimeFloat.xcodeproj. XcodeGen is not required to open the project."""

import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def uid(name: str) -> str:
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()


def quote(value: str) -> str:
    if value in {"YES", "NO"}:
        return value
    plain = value and all(ch.isalnum() or ch in "._/" for ch in value) and not value.startswith("-")
    if plain:
        return value
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def block(settings, indent="\t\t\t"):
    lines = [f"{indent}buildSettings = {{"]
    for key, value in settings.items():
        if isinstance(value, list):
            lines.append(f"{indent}\t{key} = (")
            for item in value:
                lines.append(f"{indent}\t\t{quote(str(item))},")
            lines.append(f"{indent}\t);")
        else:
            lines.append(f"{indent}\t{key} = {quote(str(value))};")
    lines.append(f"{indent}}};")
    return "\n".join(lines)


def swift_files(folder):
    return sorted(path.relative_to(ROOT).as_posix() for path in (ROOT / folder).rglob("*.swift"))


def resources(folder):
    found = []
    base = ROOT / folder
    for path in sorted(base.rglob("*")):
        if path.is_dir() and path.suffix == ".xcassets":
            found.append(path.relative_to(ROOT).as_posix())
        elif path.is_file() and path.suffix == ".xcprivacy":
            found.append(path.relative_to(ROOT).as_posix())
    return found


app_sources = swift_files("TimeFloat") + swift_files("Shared")
widget_sources = swift_files("TimeFloatWidget") + swift_files("Shared")
app_resources = resources("TimeFloat")
widget_resources = resources("TimeFloatWidget")
loose = [
    "Config/Shared.xcconfig",
    "TimeFloat/Info.plist",
    "TimeFloat/TimeFloat.entitlements",
    "TimeFloatWidget/Info.plist",
    "TimeFloatWidget/TimeFloatWidget.entitlements",
]

all_files = list(dict.fromkeys(app_sources + widget_sources + app_resources + widget_resources + loose))
refs = {rel: uid("file:" + rel) for rel in all_files}
app_product = uid("product:app")
widget_product = uid("product:widget")


def ftype(rel):
    if rel.endswith(".swift"):
        return "sourcecode.swift"
    if rel.endswith(".entitlements"):
        return "text.plist.entitlements"
    if rel.endswith(".xcconfig"):
        return "text.xcconfig"
    if rel.endswith(".xcassets"):
        return "folder.assetcatalog"
    return "text.plist.xml"


lines = []


def emit(text=""):
    lines.append(text)


emit("// !$*UTF8*$!")
emit("{")
emit("\tarchiveVersion = 1;")
emit("\tclasses = {")
emit("\t};")
emit("\tobjectVersion = 56;")
emit("\tobjects = {")
emit("")
emit("/* Begin PBXBuildFile section */")

build_ids = {}


def add_build(key, ref, comment, settings=""):
    ident = uid("build:" + key)
    build_ids[key] = ident
    extra = f" settings = {settings}; " if settings else " "
    emit(f"\t\t{ident} /* {comment} */ = {{isa = PBXBuildFile; fileRef = {ref} /* {comment.split(' in ')[0]} */;{extra}}};")
    return ident


for rel in app_sources:
    add_build("app-src:" + rel, refs[rel], f"{Path(rel).name} in Sources")
for rel in app_resources:
    add_build("app-res:" + rel, refs[rel], f"{Path(rel).name} in Resources")
for rel in widget_sources:
    add_build("widget-src:" + rel, refs[rel], f"{Path(rel).name} in Sources")
for rel in widget_resources:
    add_build("widget-res:" + rel, refs[rel], f"{Path(rel).name} in Resources")
add_build(
    "embed",
    widget_product,
    "TimeFloatWidget.appex in Embed Foundation Extensions",
    "{ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy, ); }",
)
emit("/* End PBXBuildFile section */")
emit("")
emit("/* Begin PBXFileReference section */")
for rel in all_files:
    emit(
        f"\t\t{refs[rel]} /* {Path(rel).name} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype(rel)}; path = {quote(Path(rel).name)}; sourceTree = \"<group>\"; }};"
    )
emit(
    f"\t\t{app_product} /* TimeFloat.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = TimeFloat.app; sourceTree = BUILT_PRODUCTS_DIR; }};"
)
emit(
    f"\t\t{widget_product} /* TimeFloatWidget.appex */ = {{isa = PBXFileReference; explicitFileType = \"wrapper.app-extension\"; includeInIndex = 0; path = TimeFloatWidget.appex; sourceTree = BUILT_PRODUCTS_DIR; }};"
)
emit("/* End PBXFileReference section */")
emit("")

# Groups mirror directories. A directory group owns its child groups and immediate files.
dir_children = {}
for rel in all_files:
    parts = Path(rel).parts
    for index in range(len(parts) - 1):
        parent = "/".join(parts[:index]) if index else ""
        child = "/".join(parts[: index + 1])
        dir_children.setdefault(parent, {"dirs": set(), "files": []})
        dir_children[parent]["dirs"].add(child)
        dir_children.setdefault(child, {"dirs": set(), "files": []})
    parent = "/".join(parts[:-1])
    dir_children.setdefault(parent, {"dirs": set(), "files": []})
    dir_children[parent]["files"].append(rel)

group_ids = {key: uid("group:" + (key or "<root>")) for key in dir_children}
products_group = uid("group:products")

emit("/* Begin PBXGroup section */")
for key in sorted(dir_children, key=lambda item: (item.count("/"), item)):
    info = dir_children[key]
    child_ids = []
    for child in sorted(info["dirs"]):
        child_ids.append(f"\t\t\t\t{group_ids[child]} /* {Path(child).name} */,")
    for rel in sorted(info["files"]):
        child_ids.append(f"\t\t\t\t{refs[rel]} /* {Path(rel).name} */,")
    name = Path(key).name if key else ""
    path_line = f"\t\t\tpath = {quote(name)};\n" if key else ""
    name_line = f"\t\t\tname = {quote(name)};\n" if key else ""
    joined = "\n".join(child_ids)
    emit(
        f"\t\t{group_ids[key]} /* {name or 'root'} */ = {{\n"
        f"\t\t\tisa = PBXGroup;\n"
        f"\t\t\tchildren = (\n{joined}\n\t\t\t);\n"
        f"{name_line}{path_line}"
        f"\t\t\tsourceTree = \"<group>\";\n"
        f"\t\t}};"
    )

# Root also lists Products. Rebuild root children to include the products group.
root_info = dir_children[""]
root_lines = [f"\t\t\t\t{group_ids[child]} /* {Path(child).name} */," for child in sorted(root_info["dirs"])]
root_lines += [f"\t\t\t\t{refs[rel]} /* {Path(rel).name} */," for rel in sorted(root_info["files"])]
root_lines.append(f"\t\t\t\t{products_group} /* Products */,")
# Replace the previously emitted root group by emitting a corrected one with a new approach:
# The root was already emitted. We'll instead not have emitted a duplicate if I remove it.
# Simpler: the loop already emitted root without Products. Patch after generation.
emit(
    f"\t\t{products_group} /* Products */ = {{\n"
    f"\t\t\tisa = PBXGroup;\n"
    f"\t\t\tchildren = (\n"
    f"\t\t\t\t{app_product} /* TimeFloat.app */,\n"
    f"\t\t\t\t{widget_product} /* TimeFloatWidget.appex */,\n"
    f"\t\t\t);\n"
    f"\t\t\tname = Products;\n"
    f"\t\t\tsourceTree = \"<group>\";\n"
    f"\t\t}};"
)
emit("/* End PBXGroup section */")

# Fix root group: insert products child if missing.
text_so_far = "\n".join(lines)
root_id = group_ids[""]
needle = f"{root_id} /* root */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n"
if needle not in text_so_far:
    raise SystemExit("root group not found")
# We'll do the insertion after the full file is assembled.

def phase(ident_key, isa, files, extra=""):
    ident = uid(ident_key)
    body = "\n".join(f"\t\t\t\t{build_ids[key]} /* {key} */," for key in files)
    emit(
        f"\t\t{ident} /* {ident_key} */ = {{\n"
        f"\t\t\tisa = {isa};\n"
        f"\t\t\tbuildActionMask = 2147483647;\n"
        f"\t\t\tfiles = (\n{body}\n\t\t\t);\n"
        f"{extra}"
        f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        f"\t\t}};"
    )
    return ident


emit("")
emit("/* Begin PBXSourcesBuildPhase section */")
app_sources_phase = phase("App Sources", "PBXSourcesBuildPhase", ["app-src:" + rel for rel in app_sources])
widget_sources_phase = phase("Widget Sources", "PBXSourcesBuildPhase", ["widget-src:" + rel for rel in widget_sources])
emit("/* End PBXSourcesBuildPhase section */")
emit("")
emit("/* Begin PBXResourcesBuildPhase section */")
app_resources_phase = phase("App Resources", "PBXResourcesBuildPhase", ["app-res:" + rel for rel in app_resources])
widget_resources_phase = phase("Widget Resources", "PBXResourcesBuildPhase", ["widget-res:" + rel for rel in widget_resources])
emit("/* End PBXResourcesBuildPhase section */")
emit("")
emit("/* Begin PBXFrameworksBuildPhase section */")
app_frameworks = uid("phase:app-frameworks")
widget_frameworks = uid("phase:widget-frameworks")
for ident, title in ((app_frameworks, "App Frameworks"), (widget_frameworks, "Widget Frameworks")):
    emit(
        f"\t\t{ident} /* {title} */ = {{\n"
        f"\t\t\tisa = PBXFrameworksBuildPhase;\n"
        f"\t\t\tbuildActionMask = 2147483647;\n"
        f"\t\t\tfiles = (\n\t\t\t);\n"
        f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        f"\t\t}};"
    )
emit("/* End PBXFrameworksBuildPhase section */")
emit("")
emit("/* Begin PBXCopyFilesBuildPhase section */")
embed_phase = uid("phase:embed")
emit(
    f"\t\t{embed_phase} /* Embed Foundation Extensions */ = {{\n"
    f"\t\t\tisa = PBXCopyFilesBuildPhase;\n"
    f"\t\t\tbuildActionMask = 2147483647;\n"
    f"\t\t\tdstPath = \"\";\n"
    f"\t\t\tdstSubfolderSpec = 13;\n"
    f"\t\t\tfiles = (\n\t\t\t\t{build_ids['embed']} /* TimeFloatWidget.appex in Embed Foundation Extensions */,\n\t\t\t);\n"
    f"\t\t\tname = \"Embed Foundation Extensions\";\n"
    f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
    f"\t\t}};"
)
emit("/* End PBXCopyFilesBuildPhase section */")

app_target = uid("target:app")
widget_target = uid("target:widget")
proxy = uid("proxy:widget")
dependency = uid("dependency:widget")

emit("")
emit("/* Begin PBXContainerItemProxy section */")
emit(
    f"\t\t{proxy} /* PBXContainerItemProxy */ = {{\n"
    f"\t\t\tisa = PBXContainerItemProxy;\n"
    f"\t\t\tcontainerPortal = {uid('project')} /* Project object */;\n"
    f"\t\t\tproxyType = 1;\n"
    f"\t\t\tremoteGlobalIDString = {widget_target};\n"
    f"\t\t\tremoteInfo = TimeFloatWidget;\n"
    f"\t\t}};"
)
emit("/* End PBXContainerItemProxy section */")
emit("")
emit("/* Begin PBXTargetDependency section */")
emit(
    f"\t\t{dependency} /* PBXTargetDependency */ = {{\n"
    f"\t\t\tisa = PBXTargetDependency;\n"
    f"\t\t\ttarget = {widget_target} /* TimeFloatWidget */;\n"
    f"\t\t\ttargetProxy = {proxy} /* PBXContainerItemProxy */;\n"
    f"\t\t}};"
)
emit("/* End PBXTargetDependency section */")

project_debug = uid("config:project:debug")
project_release = uid("config:project:release")
app_debug = uid("config:app:debug")
app_release = uid("config:app:release")
widget_debug = uid("config:widget:debug")
widget_release = uid("config:widget:release")
project_list = uid("list:project")
app_list = uid("list:app")
widget_list = uid("list:widget")
xcconfig_ref = refs["Config/Shared.xcconfig"]

common_project = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "CLANG_ANALYZER_NONNULL": "YES",
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "CLANG_ENABLE_OBJC_WEAK": "YES",
    "CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING": "YES",
    "CLANG_WARN_BOOL_CONVERSION": "YES",
    "CLANG_WARN_COMMA": "YES",
    "CLANG_WARN_CONSTANT_CONVERSION": "YES",
    "CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS": "YES",
    "CLANG_WARN_EMPTY_BODY": "YES",
    "CLANG_WARN_ENUM_CONVERSION": "YES",
    "CLANG_WARN_INFINITE_RECURSION": "YES",
    "CLANG_WARN_INT_CONVERSION": "YES",
    "CLANG_WARN_NON_LITERAL_NULL_CONVERSION": "YES",
    "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF": "YES",
    "CLANG_WARN_OBJC_LITERAL_CONVERSION": "YES",
    "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER": "YES",
    "CLANG_WARN_RANGE_LOOP_ANALYSIS": "YES",
    "CLANG_WARN_STRICT_PROTOTYPES": "YES",
    "CLANG_WARN_SUSPICIOUS_MOVE": "YES",
    "CLANG_WARN_UNREACHABLE_CODE": "YES",
    "COPY_PHASE_STRIP": "NO",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
    "GCC_C_LANGUAGE_STANDARD": "gnu17",
    "GCC_NO_COMMON_BLOCKS": "YES",
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
    "SDKROOT": "iphoneos",
    "SWIFT_VERSION": "5.0",
    "TARGETED_DEVICE_FAMILY": "1,2",
    "ENABLE_PREVIEWS": "YES",
}

debug_project = {
    **common_project,
    "DEBUG_INFORMATION_FORMAT": "dwarf",
    "ENABLE_TESTABILITY": "YES",
    "GCC_DYNAMIC_NO_PIC": "NO",
    "GCC_OPTIMIZATION_LEVEL": "0",
    "GCC_PREPROCESSOR_DEFINITIONS": ["DEBUG=1", "$(inherited)"],
    "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
    "ONLY_ACTIVE_ARCH": "YES",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
    "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
}
release_project = {
    **common_project,
    "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
    "ENABLE_NS_ASSERTIONS": "NO",
    "GCC_OPTIMIZATION_LEVEL": "s",
    "MTL_ENABLE_DEBUG_INFO": "NO",
    "SWIFT_COMPILATION_MODE": "wholemodule",
    "SWIFT_OPTIMIZATION_LEVEL": "-O",
    "VALIDATE_PRODUCT": "YES",
}

app_settings = {
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
    "CODE_SIGN_ENTITLEMENTS": "TimeFloat/TimeFloat.entitlements",
    "CURRENT_PROJECT_VERSION": "1",
    "GENERATE_INFOPLIST_FILE": "NO",
    "INFOPLIST_FILE": "TimeFloat/Info.plist",
    "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"],
    "MARKETING_VERSION": "1.0",
    "PRODUCT_BUNDLE_IDENTIFIER": "$(APP_BUNDLE_ID)",
    "PRODUCT_NAME": "$(TARGET_NAME)",
    "SUPPORTS_MACCATALYST": "NO",
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "SWIFT_VERSION": "5.0",
    "TARGETED_DEVICE_FAMILY": "1,2",
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
}
widget_settings = {
    "APPLICATION_EXTENSION_API_ONLY": "YES",
    "CODE_SIGN_ENTITLEMENTS": "TimeFloatWidget/TimeFloatWidget.entitlements",
    "CURRENT_PROJECT_VERSION": "1",
    "GENERATE_INFOPLIST_FILE": "NO",
    "INFOPLIST_FILE": "TimeFloatWidget/Info.plist",
    "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks", "@executable_path/../../Frameworks"],
    "MARKETING_VERSION": "1.0",
    "PRODUCT_BUNDLE_IDENTIFIER": "$(WIDGET_BUNDLE_ID)",
    "PRODUCT_NAME": "$(TARGET_NAME)",
    "SKIP_INSTALL": "YES",
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "SWIFT_VERSION": "5.0",
    "TARGETED_DEVICE_FAMILY": "1,2",
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
}


def config(ident, name, settings, base):
    emit(
        f"\t\t{ident} /* {name} */ = {{\n"
        f"\t\t\tisa = XCBuildConfiguration;\n"
        f"\t\t\tbaseConfigurationReference = {xcconfig_ref} /* Shared.xcconfig */;\n"
        f"{block(settings)}\n"
        f"\t\t\tname = {name};\n"
        f"\t\t}};"
    )


emit("")
emit("/* Begin XCBuildConfiguration section */")
config(project_debug, "Debug", debug_project, xcconfig_ref)
config(project_release, "Release", release_project, xcconfig_ref)
config(app_debug, "Debug", app_settings, xcconfig_ref)
config(app_release, "Release", app_settings, xcconfig_ref)
config(widget_debug, "Debug", widget_settings, xcconfig_ref)
config(widget_release, "Release", widget_settings, xcconfig_ref)
emit("/* End XCBuildConfiguration section */")
emit("")
emit("/* Begin XCConfigurationList section */")
for ident, label, debug, release in (
    (project_list, "Project", project_debug, project_release),
    (app_list, "App", app_debug, app_release),
    (widget_list, "Widget", widget_debug, widget_release),
):
    emit(
        f"\t\t{ident} /* Build configuration list for {label} */ = {{\n"
        f"\t\t\tisa = XCConfigurationList;\n"
        f"\t\t\tbuildConfigurations = (\n"
        f"\t\t\t\t{debug} /* Debug */,\n"
        f"\t\t\t\t{release} /* Release */,\n"
        f"\t\t\t);\n"
        f"\t\t\tdefaultConfigurationIsVisible = 0;\n"
        f"\t\t\tdefaultConfigurationName = Release;\n"
        f"\t\t}};"
    )
emit("/* End XCConfigurationList section */")

project_id = uid("project")
emit("")
emit("/* Begin PBXNativeTarget section */")
emit(
    f"\t\t{app_target} /* TimeFloat */ = {{\n"
    f"\t\t\tisa = PBXNativeTarget;\n"
    f"\t\t\tbuildConfigurationList = {app_list} /* Build configuration list for App */;\n"
    f"\t\t\tbuildPhases = (\n"
    f"\t\t\t\t{app_sources_phase} /* App Sources */,\n"
    f"\t\t\t\t{app_frameworks} /* App Frameworks */,\n"
    f"\t\t\t\t{app_resources_phase} /* App Resources */,\n"
    f"\t\t\t\t{embed_phase} /* Embed Foundation Extensions */,\n"
    f"\t\t\t);\n"
    f"\t\t\tbuildRules = (\n\t\t\t);\n"
    f"\t\t\tdependencies = (\n\t\t\t\t{dependency} /* PBXTargetDependency */,\n\t\t\t);\n"
    f"\t\t\tname = TimeFloat;\n"
    f"\t\t\tproductName = TimeFloat;\n"
    f"\t\t\tproductReference = {app_product} /* TimeFloat.app */;\n"
    f"\t\t\tproductType = \"com.apple.product-type.application\";\n"
    f"\t\t}};"
)
emit(
    f"\t\t{widget_target} /* TimeFloatWidget */ = {{\n"
    f"\t\t\tisa = PBXNativeTarget;\n"
    f"\t\t\tbuildConfigurationList = {widget_list} /* Build configuration list for Widget */;\n"
    f"\t\t\tbuildPhases = (\n"
    f"\t\t\t\t{widget_sources_phase} /* Widget Sources */,\n"
    f"\t\t\t\t{widget_frameworks} /* Widget Frameworks */,\n"
    f"\t\t\t\t{widget_resources_phase} /* Widget Resources */,\n"
    f"\t\t\t);\n"
    f"\t\t\tbuildRules = (\n\t\t\t);\n"
    f"\t\t\tdependencies = (\n\t\t\t);\n"
    f"\t\t\tname = TimeFloatWidget;\n"
    f"\t\t\tproductName = TimeFloatWidget;\n"
    f"\t\t\tproductReference = {widget_product} /* TimeFloatWidget.appex */;\n"
    f"\t\t\tproductType = \"com.apple.product-type.app-extension\";\n"
    f"\t\t}};"
)
emit("/* End PBXNativeTarget section */")
emit("")
emit("/* Begin PBXProject section */")
emit(
    f"\t\t{project_id} /* Project object */ = {{\n"
    f"\t\t\tisa = PBXProject;\n"
    f"\t\t\tattributes = {{\n"
    f"\t\t\t\tBuildIndependentTargetsInParallel = 1;\n"
    f"\t\t\t\tLastUpgradeCheck = 1600;\n"
    f"\t\t\t\tTargetAttributes = {{\n"
    f"\t\t\t\t\t{app_target} = {{ CreatedOnToolsVersion = 16.0; }};\n"
    f"\t\t\t\t\t{widget_target} = {{ CreatedOnToolsVersion = 16.0; }};\n"
    f"\t\t\t\t}};\n"
    f"\t\t\t}};\n"
    f"\t\t\tbuildConfigurationList = {project_list} /* Build configuration list for Project */;\n"
    f"\t\t\tcompatibilityVersion = \"Xcode 14.0\";\n"
    f"\t\t\tdevelopmentRegion = \"zh-Hans\";\n"
    f"\t\t\thasScannedForEncodings = 0;\n"
    f"\t\t\tknownRegions = (\n\t\t\t\ten,\n\t\t\t\tBase,\n\t\t\t\t\"zh-Hans\",\n\t\t\t);\n"
    f"\t\t\tmainGroup = {group_ids['']} /* root */;\n"
    f"\t\t\tproductRefGroup = {products_group} /* Products */;\n"
    f"\t\t\tprojectDirPath = \"\";\n"
    f"\t\t\tprojectRoot = \"\";\n"
    f"\t\t\ttargets = (\n"
    f"\t\t\t\t{app_target} /* TimeFloat */,\n"
    f"\t\t\t\t{widget_target} /* TimeFloatWidget */,\n"
    f"\t\t\t);\n"
    f"\t\t}};"
)
emit("/* End PBXProject section */")
emit("\t};")
emit(f"\trootObject = {project_id} /* Project object */;")
emit("}")

text = "\n".join(lines) + "\n"
old = (
    f"{root_id} /* root */ = {{\n"
    f"\t\t\tisa = PBXGroup;\n"
    f"\t\t\tchildren = (\n"
)
new = old + f"\t\t\t\t{products_group} /* Products */,\n"
if old not in text:
    raise SystemExit("could not patch root group")
text = text.replace(old, new, 1)

out = ROOT / "TimeFloat.xcodeproj" / "project.pbxproj"
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(text)
print(f"wrote {out}")
print(f"app sources {len(app_sources)} widget sources {len(widget_sources)}")
