#!/usr/bin/env python3
"""Reject an iOS app whose embedded runtime exceeds its declared minimum OS."""

from __future__ import annotations

import argparse
import plistlib
import re
import subprocess
from pathlib import Path


VERSION_RE = re.compile(r"^\s*(?:minos|version)\s+(\d+(?:\.\d+){1,2})\s*$", re.MULTILINE)


def version_tuple(value: str) -> tuple[int, int, int]:
    parts = [int(part) for part in value.split(".")]
    if len(parts) not in (2, 3):
        raise ValueError(f"invalid version: {value}")
    return tuple((parts + [0, 0])[:3])


def version_string(value: tuple[int, int, int]) -> str:
    return ".".join(str(part) for part in value)


def macho_minimum(path: Path) -> tuple[int, int, int]:
    output = subprocess.run(
        ["xcrun", "vtool", "-show-build", str(path)],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    if "platform IOS" not in output and "LC_VERSION_MIN_IPHONEOS" not in output:
        raise SystemExit(f"minimum-version audit failed: not an iOS image: {path.name}")
    match = VERSION_RE.search(output)
    if not match:
        raise SystemExit(f"minimum-version audit failed: no minimum OS: {path.name}")
    return version_tuple(match.group(1))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--app", type=Path, required=True)
    parser.add_argument("--expected", required=True)
    args = parser.parse_args()

    expected = version_tuple(args.expected)
    info_path = args.app / "Info.plist"
    executable = args.app / "UT99Apple"
    frameworks = args.app / "Frameworks"
    engine = frameworks / "UnrealTournament.dylib"
    metallib = args.app / "default.metallib"
    for required in (info_path, executable, engine, metallib):
        if not required.is_file():
            raise SystemExit(f"minimum-version audit failed: missing {required}")

    with info_path.open("rb") as handle:
        declared = plistlib.load(handle).get("MinimumOSVersion")
    if declared is None or version_tuple(str(declared)) != expected:
        raise SystemExit(
            f"minimum-version audit failed: Info.plist declares {declared!r}, "
            f"expected {args.expected}"
        )

    audited = [executable, *sorted(frameworks.glob("*.dylib"))]
    versions: dict[str, tuple[int, int, int]] = {}
    for image in audited:
        minimum = macho_minimum(image)
        versions[image.name] = minimum
        if minimum > expected:
            raise SystemExit(
                f"minimum-version audit failed: {image.name} requires "
                f"{version_string(minimum)}, expected at most {args.expected}"
            )

    for exact in (executable.name, engine.name):
        if versions[exact] != expected:
            raise SystemExit(
                f"minimum-version audit failed: {exact} declares "
                f"{version_string(versions[exact])}, expected exactly {args.expected}"
            )

    metal_target = f"apple-ios{version_string(expected)}".encode()
    if metal_target not in metallib.read_bytes():
        raise SystemExit(
            "minimum-version audit failed: default.metallib does not contain "
            f"the target {metal_target.decode()}"
        )

    detail = ", ".join(
        f"{name}={version_string(minimum)}" for name, minimum in sorted(versions.items())
    )
    print(f"minimum_version_audit=passed expected={args.expected} {detail}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
