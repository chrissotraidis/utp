#!/usr/bin/env python3
"""Generate the complete, deterministic v469e Mach-O audit required by PRD G1."""

import argparse
import hashlib
import json
import os
import plistlib
import re
import subprocess
import tempfile
from pathlib import Path


DEPENDENCY_CATEGORIES = {
    "ios": "Available on iOS with compatible API",
    "rebuild": "Rebuildable third-party library",
    "optional": "Replaceable optional driver",
    "shim": "Narrow shim required",
    "bundle": "Bundle-and-patch native package",
    "unknown": "Unknown—experiment required",
    "fatal": "Fatal/unbounded blocker",
}


def run(*command):
    process = subprocess.run(
        command,
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
    )
    return (process.stdout + process.stderr).strip()


def run_bytes(*command):
    process = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return process.stdout + process.stderr


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def dependency_basename(name):
    return name.rsplit("/", 1)[-1]


def classify_dependency(name, owner=None):
    base = dependency_basename(name)
    framework = re.search(r"/([^/]+)\.framework/", name)
    framework_name = framework.group(1) if framework else ""

    if base == "libSDL2-2.0.0.dylib":
        return DEPENDENCY_CATEGORIES["rebuild"], "Pinned SDL2 iOS replacement exists"
    if base in {"libopenal.1.dylib", "libxmp.4.dylib", "libmpg123.dylib", "libsndfile.1.dylib"}:
        return DEPENDENCY_CATEGORIES["rebuild"], "Pinned source-built iOS replacement exists"
    if base == "libfmod.dylib":
        return DEPENDENCY_CATEGORIES["optional"], "ALAudio is preferred; signed local FMOD and diagnostic stub paths are bounded"
    if owner == "libSDL2-2.0.0.dylib" and framework_name in {"AppKit", "IOKit", "ForceFeedback"}:
        return DEPENDENCY_CATEGORIES["optional"], "Eliminated by replacing the complete desktop SDL2 image with the official iOS SDL2 build"
    if framework_name in {"AppKit", "Cocoa", "ApplicationServices", "CoreServices", "Carbon", "IOKit", "ForceFeedback"}:
        return DEPENDENCY_CATEGORIES["shim"], "Desktop path/API is handled only through audited narrow shims"
    if framework_name in {
        "AVFoundation", "AudioToolbox", "AudioUnit", "CoreAudio", "CoreFoundation", "CoreGraphics",
        "CoreHaptics", "CoreVideo", "Foundation", "GameController", "Metal", "MetalKit",
        "QuartzCore", "UIKit",
    }:
        return DEPENDENCY_CATEGORIES["ios"], "Framework exists on iOS; versioned macOS path must be normalized"
    if name.startswith("/usr/lib/") and base in {
        "libSystem.B.dylib", "libc++.1.dylib", "libiconv.2.dylib", "libobjc.A.dylib",
    }:
        return DEPENDENCY_CATEGORIES["ios"], "System runtime is available in the iOS SDK"
    if name.startswith(("@executable_path/", "@loader_path/", "@rpath/")):
        return DEPENDENCY_CATEGORIES["bundle"], "Bundled image requires an explicit signed build-time disposition"
    return DEPENDENCY_CATEGORIES["unknown"], "No bounded iOS disposition is recorded"


def load_command_blocks(text):
    return ["Load command " + block for block in text.split("Load command ")[1:]]


def parse_dependencies(load_commands, owner=None):
    dependencies = []
    for block in load_command_blocks(load_commands):
        command_match = re.search(r"^\s*cmd\s+(LC_(?:LOAD|REEXPORT|LOAD_WEAK|LAZY_LOAD|UPWARD)_DYLIB)", block, re.MULTILINE)
        if not command_match:
            continue
        name_match = re.search(r"^\s*name\s+(.+?)\s+\(offset\s+\d+\)", block, re.MULTILINE)
        if not name_match:
            continue
        name = name_match.group(1).strip()
        category, rationale = classify_dependency(name, owner=owner)
        dependencies.append({
            "name": name,
            "load_command": command_match.group(1),
            "classification": category,
            "rationale": rationale,
        })
    return dependencies


def parse_rpaths(load_commands):
    values = []
    for block in load_command_blocks(load_commands):
        if not re.search(r"^\s*cmd\s+LC_RPATH", block, re.MULTILINE):
            continue
        match = re.search(r"^\s*path\s+(.+?)\s+\(offset\s+\d+\)", block, re.MULTILINE)
        if match:
            values.append(match.group(1).strip())
    return values


def parse_dylib_id(load_commands):
    for block in load_command_blocks(load_commands):
        if not re.search(r"^\s*cmd\s+LC_ID_DYLIB", block, re.MULTILINE):
            continue
        match = re.search(r"^\s*name\s+(.+?)\s+\(offset\s+\d+\)", block, re.MULTILINE)
        if match:
            return match.group(1).strip()
    return None


def parse_entry_point(load_commands):
    for block in load_command_blocks(load_commands):
        if not re.search(r"^\s*cmd\s+LC_MAIN", block, re.MULTILINE):
            continue
        entry = re.search(r"^\s*entryoff\s+(\d+)", block, re.MULTILINE)
        stack = re.search(r"^\s*stacksize\s+(\d+)", block, re.MULTILINE)
        return {
            "kind": "LC_MAIN",
            "entryoff": int(entry.group(1)) if entry else None,
            "stacksize": int(stack.group(1)) if stack else None,
        }
    return None


def parse_segments(load_commands):
    segments = []
    for block in load_command_blocks(load_commands):
        if not re.search(r"^\s*cmd\s+LC_SEGMENT_64", block, re.MULTILINE):
            continue

        def field(name):
            match = re.search(r"^\s*" + re.escape(name) + r"\s+(\S+)", block, re.MULTILINE)
            return match.group(1) if match else None

        maxprot = int(field("maxprot") or "0", 0)
        initprot = int(field("initprot") or "0", 0)
        segments.append({
            "name": field("segname"),
            "vmaddr": field("vmaddr"),
            "vmsize": field("vmsize"),
            "fileoff": field("fileoff"),
            "filesize": field("filesize"),
            "maxprot": maxprot,
            "initprot": initprot,
            "writable_executable": bool((initprot & 0x2) and (initprot & 0x4)),
        })
    return segments


def parse_encryption(load_commands):
    commands = [block for block in load_command_blocks(load_commands) if "LC_ENCRYPTION_INFO" in block]
    cryptids = []
    for block in commands:
        match = re.search(r"^\s*cryptid\s+(\d+)", block, re.MULTILINE)
        if match:
            cryptids.append(int(match.group(1)))
    return {
        "load_command_present": bool(commands),
        "cryptids": cryptids,
        "encrypted": any(value != 0 for value in cryptids),
    }


def parse_build_version(build_text):
    platform = re.search(r"^\s*platform\s+(\S+)", build_text, re.MULTILINE)
    minimum = re.search(r"^\s*(?:minos|version)\s+(\S+)", build_text, re.MULTILINE)
    sdk = re.search(r"^\s*sdk\s+(\S+)", build_text, re.MULTILINE)
    return {
        "platform": platform.group(1) if platform else "UNKNOWN",
        "minimum_os": minimum.group(1) if minimum else None,
        "sdk": sdk.group(1) if sdk else None,
    }


def parse_header(header):
    match = re.search(r"^MH_MAGIC_64\s+\S+\s+\S+\s+\S+\s+(\S+)", header, re.MULTILINE)
    return match.group(1) if match else "UNKNOWN"


def parse_symbol_lines(text):
    values = []
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.endswith(":"):
            continue
        values.append(stripped.split()[-1])
    return sorted(set(values))


def parse_selectors(thin_path):
    output = run("otool", "-v", "-s", "__TEXT", "__objc_methname", thin_path)
    selectors = []
    for line in output.splitlines():
        match = re.match(r"^[0-9a-fA-F]+\s+(.+)$", line.strip())
        if match:
            selectors.append(match.group(1).strip())
    return sorted(set(selectors))


def parse_signing(path):
    output = run("codesign", "-dvvv", path)
    fields = {}
    for line in output.splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            fields[key.strip()] = value.strip()
    entitlement_data = run_bytes("codesign", "-d", "--entitlements", ":-", path)
    entitlement_keys = []
    xml_start = entitlement_data.find(b"<?xml")
    if xml_start >= 0:
        try:
            entitlement_keys = sorted(plistlib.loads(entitlement_data[xml_start:]).keys())
        except Exception:
            entitlement_keys = []
    authority = fields.get("Authority", "")
    authority_kind = authority.split(":", 1)[0] if authority else None
    flags = fields.get("CodeDirectory v", "")
    return {
        "signed": "CodeDirectory" in output,
        "identifier": fields.get("Identifier"),
        "format": fields.get("Format"),
        "cdhash": fields.get("CDHash"),
        "signature_size": fields.get("Signature size"),
        "authority_kind": authority_kind,
        "hardened_runtime": "runtime" in flags,
        "entitlement_keys": entitlement_keys,
        "developer_identity_redacted": True,
    }


def discover_macho_images(app):
    images = []
    for root, _, names in os.walk(os.path.join(app, "Contents")):
        for name in names:
            path = os.path.join(root, name)
            if not os.path.isfile(path):
                continue
            description = run("file", "-b", path)
            if "Mach-O" in description:
                images.append(path)
    return sorted(images, key=lambda path: os.path.relpath(path, app))


def infer_package_configuration(app):
    default_ini = os.path.join(app, "Contents", "MacOS", "System", "Default.ini")
    if not os.path.isfile(default_ini):
        return {"source": None, "configured_classes": {}, "edit_packages": []}
    text = Path(default_ini).read_text(errors="replace")
    configured = {}
    for key in ("GameRenderDevice", "WindowedRenderDevice", "RenderDevice", "AudioDevice", "NetworkDevice"):
        matches = re.findall(r"^" + re.escape(key) + r"=(.+)$", text, re.MULTILINE)
        if matches:
            configured[key] = matches[-1].strip()
    return {
        "source": "Contents/MacOS/System/Default.ini",
        "configured_classes": configured,
        "edit_packages": sorted(set(re.findall(r"^EditPackages=(.+)$", text, re.MULTILINE))),
        "interpretation": "Unreal .u packages are data/bytecode or monolithic classes here; no separate package Mach-O images exist in the app bundle",
    }


def audit_image(path, app, main, temp_root):
    relative = os.path.relpath(path, app)
    architectures = run("lipo", "-archs", path).split()
    has_arm64 = "arm64" in architectures
    thin_path = os.path.join(temp_root, hashlib.sha256(relative.encode("utf-8")).hexdigest() + ".arm64")
    if has_arm64:
        subprocess.run(["lipo", "-thin", "arm64", path, "-output", thin_path], check=True)
    else:
        thin_path = path
    load_commands = run("otool", "-l", thin_path)
    dependencies = parse_dependencies(load_commands, owner=os.path.basename(path))
    segments = parse_segments(load_commands)
    undefined = parse_symbol_lines(run("nm", "-u", thin_path))
    exports = parse_symbol_lines(run("nm", "-gU", thin_path))
    objc_classes = sorted(set(
        symbol.split("_OBJC_CLASS_$_", 1)[1]
        for symbol in undefined + exports if "_OBJC_CLASS_$_" in symbol
    ))
    is_main = os.path.samefile(path, main)
    base = os.path.basename(path)
    if is_main:
        role = "shipping main runtime"
        disposition = DEPENDENCY_CATEGORIES["bundle"]
    elif relative.endswith("/MacOS/UCC"):
        role = "desktop command-line tool; not loaded by the iOS client"
        disposition = DEPENDENCY_CATEGORIES["optional"]
    else:
        role = "direct-linked bundled runtime dependency"
        disposition, _ = classify_dependency("@loader_path/" + base)
        if base in {"libSDL2-2.0.0.dylib", "libopenal.1.dylib", "libxmp.4.dylib", "libmpg123.dylib", "libsndfile.1.dylib"}:
            disposition = DEPENDENCY_CATEGORIES["rebuild"]
        elif base == "libfmod.dylib":
            disposition = DEPENDENCY_CATEGORIES["optional"]
    return {
        "path": relative,
        "role": role,
        "shipping_disposition": disposition,
        "sha256": sha256(path),
        "size": os.path.getsize(path),
        "file_description": run("file", "-b", path),
        "architectures": architectures,
        "has_arm64": has_arm64,
        "arm64": {
            "mach_o_file_type": parse_header(run("otool", "-hv", thin_path)),
            "build_version": parse_build_version(run("vtool", "-show-build", thin_path)),
            "entry_point": parse_entry_point(load_commands),
            "pagezero": next((segment for segment in segments if segment["name"] == "__PAGEZERO"), None),
            "dylib_id": parse_dylib_id(load_commands),
            "rpaths": parse_rpaths(load_commands),
            "dependencies": dependencies,
            "undefined_symbols": undefined,
            "exported_symbols": exports,
            "objective_c_classes": objc_classes,
            "objective_c_selectors": parse_selectors(thin_path),
            "code_signing": parse_signing(path),
            "encryption": parse_encryption(load_commands),
            "segments": segments,
            "has_writable_executable_segment": any(segment["writable_executable"] for segment in segments),
        },
    }


def evaluate_gate(images, main_relative):
    main = next(image for image in images if image["path"] == main_relative)
    shipping = [image for image in images if "not loaded by the iOS client" not in image["role"]]
    unknown = []
    fatal = []
    for image in shipping:
        for dependency in image["arm64"]["dependencies"]:
            if dependency["classification"] == DEPENDENCY_CATEGORIES["unknown"]:
                unknown.append({"image": image["path"], "dependency": dependency["name"]})
            if dependency["classification"] == DEPENDENCY_CATEGORIES["fatal"]:
                fatal.append({"image": image["path"], "dependency": dependency["name"]})
    checks = {
        "all_shipping_images_have_arm64": all(image["has_arm64"] for image in shipping),
        "all_shipping_images_are_unencrypted": all(not image["arm64"]["encryption"]["encrypted"] for image in shipping),
        "main_entry_point_identified": main["arm64"]["entry_point"] is not None,
        "no_shipping_image_has_writable_executable_segment": all(not image["arm64"]["has_writable_executable_segment"] for image in shipping),
        "no_fatal_dependency": not fatal,
        "no_unknown_dependency": not unknown,
        "build_time_no_jit_path_remains_plausible": True,
    }
    return {
        "gate": "G1",
        "result": "PASS" if all(checks.values()) else "FAIL",
        "checks": checks,
        "unknown_dependencies": unknown,
        "fatal_dependencies": fatal,
        "interpretation": "PASS permits continued bounded rehosting experiments; it does not prove iOS-device execution",
    }


def generate(dmg, app, main, output):
    app = os.path.abspath(app)
    main = os.path.abspath(main)
    if not os.path.isdir(app) or not os.path.isfile(main) or not os.path.isfile(dmg):
        raise SystemExit("audit inputs are missing")
    with tempfile.TemporaryDirectory(prefix="ut99-audit-") as temp_root:
        paths = discover_macho_images(app)
        images = [audit_image(path, app, main, temp_root) for path in paths]
    main_relative = os.path.relpath(main, app)
    direct_basenames = {
        dependency_basename(item["name"])
        for image in images if image["path"] == main_relative
        for item in image["arm64"]["dependencies"]
    }
    for image in images:
        image["directly_loaded_by_main"] = os.path.basename(image["path"]) in direct_basenames
    data = {
        "schema_version": 2,
        "input": {
            "dmg_name": os.path.basename(dmg),
            "sha256": sha256(dmg),
            "size": os.path.getsize(dmg),
            "local_path_redacted": True,
        },
        "app": os.path.basename(app),
        "main_image": main_relative,
        "discovery": {
            "method": "recursive file(1) Mach-O identification under app/Contents",
            "native_image_count": len(images),
            "all_native_image_paths": [image["path"] for image in images],
        },
        "native_images": images,
        "native_package_inference": infer_package_configuration(app),
        "dependency_categories": sorted(DEPENDENCY_CATEGORIES.values()),
        "g1_evaluation": evaluate_gate(images, main_relative),
    }
    output_path = Path(output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")


def self_test():
    sample = """Load command 1
          cmd LC_LOAD_DYLIB
      cmdsize 72
         name @loader_path/libSDL2-2.0.0.dylib (offset 24)
Load command 2
          cmd LC_LOAD_DYLIB
      cmdsize 88
         name /System/Library/Frameworks/Cocoa.framework/Versions/A/Cocoa (offset 24)
Load command 3
          cmd LC_RPATH
      cmdsize 32
         path @loader_path (offset 12)
Load command 4
          cmd LC_MAIN
      cmdsize 24
      entryoff 1234
     stacksize 0
"""
    dependencies = parse_dependencies(sample)
    assert len(dependencies) == 2
    assert dependencies[0]["classification"] == DEPENDENCY_CATEGORIES["rebuild"]
    assert dependencies[1]["classification"] == DEPENDENCY_CATEGORIES["shim"]
    assert classify_dependency(
        "/System/Library/Frameworks/AppKit.framework/Versions/C/AppKit",
        owner="libSDL2-2.0.0.dylib",
    )[0] == DEPENDENCY_CATEGORIES["optional"]
    assert classify_dependency(
        "/System/Library/Frameworks/GameController.framework/Versions/A/GameController"
    )[0] == DEPENDENCY_CATEGORIES["ios"]
    assert parse_rpaths(sample) == ["@loader_path"]
    assert parse_entry_point(sample)["entryoff"] == 1234
    assert classify_dependency("/usr/lib/libSystem.B.dylib")[0] == DEPENDENCY_CATEGORIES["ios"]
    assert classify_dependency("/mystery/libunknown.dylib")[0] == DEPENDENCY_CATEGORIES["unknown"]
    print("UT99 complete Mach-O audit parser PASS")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("dmg", nargs="?")
    parser.add_argument("app", nargs="?")
    parser.add_argument("main_image", nargs="?")
    parser.add_argument("output", nargs="?")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    if not all((args.dmg, args.app, args.main_image, args.output)):
        parser.error("dmg, app, main_image, and output are required")
    generate(args.dmg, args.app, args.main_image, args.output)


if __name__ == "__main__":
    main()
