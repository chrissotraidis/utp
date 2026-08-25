#!/usr/bin/env python3
import argparse
import json
import re
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--undefined", type=Path, default=Path("build/audit/undefined-symbols.txt"))
parser.add_argument("--library", type=Path, default=Path("build/sdl2-ios/Build/Products/Release-iphonesimulator/libSDL2.a"))
parser.add_argument("--output", type=Path, default=Path("build/audit/sdl-abi.json"))
args = parser.parse_args()

needed = set()
for line in args.undefined.read_text().splitlines():
    match = re.search(r"\(undefined\) external (_SDL_[A-Za-z0-9_]+) \(from libSDL2", line)
    if match:
        needed.add(match.group(1))
symbols = subprocess.run(["nm", "-arch", "arm64", "-gU", str(args.library)], check=True, capture_output=True, text=True).stdout
provided = {match.group(1) for line in symbols.splitlines() if (match := re.search(r"\s[Tt]\s+(_SDL_[A-Za-z0-9_]+)$", line))}
missing = sorted(needed - provided)
result = {"needed_count": len(needed), "provided_count": len(provided), "missing": missing, "classification": "PASS: all observed SDL imports are exported" if not missing else "FAIL: missing SDL exports require investigation"}
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps(result, indent=2))
