#!/usr/bin/env python3
"""Build-time iOS feasibility artifact for a pristine v469e executable.

This intentionally produces a diagnostic candidate, not a shippable engine.  It
thins the official input, reuses the deterministic hosted transformation, marks
the image as iOS through vtool, rewrites the six replaceable third-party paths,
and records any remaining desktop framework dependencies.  Without
--allow-unsupported the command refuses to emit an artifact when those
dependencies remain.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import tempfile
from pathlib import Path


DESKTOP_FRAMEWORKS = (
    "/System/Library/Frameworks/Cocoa.framework",
    "/System/Library/Frameworks/ApplicationServices.framework",
    "/System/Library/Frameworks/CoreServices.framework",
)


def run(*args: str) -> str:
    result = subprocess.run(args, check=True, text=True, capture_output=True)
    return result.stdout


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def replace_load_name(path: Path, old_name: str, new_name: str) -> None:
    data = bytearray(path.read_bytes())
    old = old_name.encode()
    new = new_name.encode()
    if len(new) > len(old):
        raise SystemExit(f"replacement is longer than Mach-O load-name slot: {old_name}")
    if data.count(old) != 1:
        raise SystemExit(f"expected one Mach-O load name: {old_name}")
    index = data.index(old)
    data[index:index + len(old)] = new + b"\0" * (len(old) - len(new))
    path.write_bytes(data)


def patch_embedded_app_chdir(path: Path) -> None:
    """Make the legacy macOS executable-directory helper a no-op on iOS.

    v469e's appChdirSystem() derives ``.../Contents/MacOS/System`` from
    __NSGetExecutablePath(). In an iOS host that API returns the host app
    executable (``UT99Apple.app/UT99Apple``), while the Swift host has already
    selected and staged the real UT working directory. Returning success keeps
    the original engine's startup contract without guessing at a bundle path.
    The function is in the audited, fixed v469e input at this address and the
    bytes are checked before changing them.
    """
    data = bytearray(path.read_bytes())
    text_vmaddr = 0x100000000
    function_vmaddr = 0x1003A3BF4
    file_offset = function_vmaddr - text_vmaddr
    expected = bytes.fromhex("f4 4f be a9 fd 7b 01 a9")
    replacement = bytes.fromhex("20 00 80 52 c0 03 5f d6")
    if file_offset < 0 or data[file_offset:file_offset + len(expected)] != expected:
        raise SystemExit("unexpected v469e appChdirSystem bytes; refusing iOS compatibility patch")
    data[file_offset:file_offset + len(replacement)] = replacement
    path.write_bytes(data)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--ios-min", default=os.environ.get("UT99_IOS_MIN", "17.0"))
    parser.add_argument("--ios-sdk", default=os.environ.get("UT99_IOS_SDK", "26.5"))
    parser.add_argument("--platform", choices=("ios", "iossim"), default="ios")
    parser.add_argument("--shim", type=Path)
    parser.add_argument("--available", type=Path, action="append", default=[])
    parser.add_argument("--fmod-stub", action="store_true")
    parser.add_argument("--allow-unsupported", action="store_true")
    args = parser.parse_args()

    if not re.fullmatch(r"[0-9]+\.[0-9]+(?:\.[0-9]+)?", args.ios_min):
        raise SystemExit(f"invalid iOS minimum version: {args.ios_min}")
    if not re.fullmatch(r"[0-9]+\.[0-9]+(?:\.[0-9]+)?", args.ios_sdk):
        raise SystemExit(f"invalid iOS SDK version: {args.ios_sdk}")

    if not args.source.is_file():
        raise SystemExit(f"source does not exist: {args.source}")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.report.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="ut99-ios-artifact-") as temp:
        temp_dir = Path(temp)
        thin = temp_dir / "arm64-input"
        hosted = temp_dir / "hosted-dylib"
        hosted_report = temp_dir / "hosted.json"
        platform = temp_dir / "ios-platform-dylib"

        run("lipo", "-thin", "arm64", str(args.source), "-output", str(thin))
        run(
            "python3",
            "tools/patch_macho_hosted.py",
            str(thin),
            str(hosted),
            str(hosted_report),
            "dylib",
        )
        run(
            "xcrun",
            "vtool",
            "-set-build-version",
            args.platform,
            args.ios_min,
            args.ios_sdk,
            "-replace",
            "-output",
            str(platform),
            str(hosted),
        )
        patch_embedded_app_chdir(platform)

        # These names are deliberately limited to the libraries for which the
        # project has a concrete replacement path.  Other dependencies remain
        # visible in the report and are not silently redirected.
        replacements = {
            "@loader_path/Frameworks/libSDL2-2.0.0.dylib": "@rpath/libSDL2.dylib",
            "@loader_path/Frameworks/libopenal.1.dylib": "@rpath/libopenal.dylib",
            "@loader_path/Frameworks/libxmp.4.dylib": "@rpath/libxmp.dylib",
            "@loader_path/Frameworks/libmpg123.dylib": "@rpath/libmpg123.dylib",
            "@loader_path/Frameworks/libsndfile.1.dylib": "@rpath/libsndfile.dylib",
            "@loader_path/Frameworks/libfmod.dylib": "@rpath/libfmod.dylib",
        }
        for old, new in replacements.items():
            run("install_name_tool", "-change", old, new, str(platform))

        shim_replacements = {}
        if args.shim:
            if not args.shim.is_file():
                raise SystemExit(f"shim does not exist: {args.shim}")
            shim_names = {
                DESKTOP_FRAMEWORKS[0]: "@rpath/UT99CocoaShim.dylib",
                DESKTOP_FRAMEWORKS[1]: "@rpath/UT99ApplicationServicesShim.dylib",
                DESKTOP_FRAMEWORKS[2]: "@rpath/UT99CoreServicesShim.dylib",
            }
            for framework in DESKTOP_FRAMEWORKS:
                old = next((dependency for dependency in run("otool", "-L", str(platform)).splitlines() if framework in dependency), None)
                if old:
                    old_name = old.strip().split(" (compatibility", 1)[0]
                    shim_name = shim_names[framework]
                    run("install_name_tool", "-change", old_name, shim_name, str(platform))
                    shim_replacements[old_name] = shim_name

        # The macOS input records versioned framework bundle paths. iOS and
        # iOS Simulator expose the framework images at their flat install
        # names, so normalize only the Apple frameworks that remain in the
        # audited engine graph.
        framework_paths = {
            "/System/Library/Frameworks/Foundation.framework/Versions/C/Foundation": "/System/Library/Frameworks/Foundation.framework/Foundation",
            "/System/Library/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics": "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics",
            "/System/Library/Frameworks/MetalKit.framework/Versions/A/MetalKit": "/System/Library/Frameworks/MetalKit.framework/MetalKit",
            "/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation": "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation",
        }
        metal_names = (
            "/System/Library/Frameworks/Metal.framework/Versions/A/Metal",
            "/System/Library/Frameworks/Metal.framework/Metal",
        )
        for old_name in metal_names:
            if old_name in run("otool", "-L", str(platform)):
                run("install_name_tool", "-change", old_name, "@rpath/UT99MetalShim.dylib", str(platform))
        for old_name, new_name in framework_paths.items():
            if old_name in run("otool", "-L", str(platform)):
                replace_load_name(platform, old_name, new_name)
        if "@loader_path" not in run("otool", "-l", str(platform)):
            run("install_name_tool", "-add_rpath", "@loader_path", str(platform))

        load_output = run("otool", "-L", str(platform))
        dependencies = [line.strip().split(" (compatibility", 1)[0] for line in load_output.splitlines()[1:] if line.strip()]
        unsupported = [
            dependency
            for dependency in dependencies
            if any(framework in dependency for framework in DESKTOP_FRAMEWORKS)
        ]
        available_names = set()
        for available in args.available:
            if not available.is_file():
                raise SystemExit(f"available replacement does not exist: {available}")
            identify = run("otool", "-D", str(available)).splitlines()
            available_names.add(Path(identify[-1].strip()).name)
        missing_rpath = [
            dependency
            for dependency in dependencies
            if dependency.startswith("@rpath/") and Path(dependency).name not in available_names
        ]
        ready = not unsupported and not missing_rpath and not args.fmod_stub
        if unsupported and not args.allow_unsupported:
            raise SystemExit(
                "refusing to emit iOS artifact; unresolved desktop dependencies: "
                + ", ".join(unsupported)
                + " (use --allow-unsupported only for a diagnostic candidate)"
            )

        run("codesign", "--force", "--sign", "-", str(platform))
        platform.replace(args.output)
        report = {
            "source": str(args.source),
            "source_sha256": sha256(args.source),
            "output": str(args.output),
            "output_sha256": sha256(args.output),
            "architecture": "arm64",
            "platform": "iOS Simulator" if args.platform == "iossim" else "iOS",
            "minimum_os": args.ios_min,
            "sdk": args.ios_sdk,
            "build_time_patching": True,
            "runtime_jit": False,
            "reused_hosted_transform": True,
            "replacements": replacements,
            "shim_replacements": shim_replacements,
            "dependencies": dependencies,
            "unsupported_desktop_dependencies": unsupported,
            "available_replacement_names": sorted(available_names),
            "missing_rpath_dependencies": missing_rpath,
            "fmod_stub": args.fmod_stub,
            "ready_for_device_embedding": ready,
            "classification": "READY" if ready else "DIAGNOSTIC_ONLY_AUDIO_STUB_OR_MISSING_DEPENDENCIES",
        }
        args.report.write_text(json.dumps(report, indent=2) + "\n")

    print(json.dumps(report, indent=2))
    return 0 if ready else 0


if __name__ == "__main__":
    raise SystemExit(main())
