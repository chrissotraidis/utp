#!/usr/bin/env python3
"""Prepare a user-owned UT99 content pack without copying desktop executables."""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import tempfile
import zipfile
from pathlib import Path

CONTENT_DIRS = ("Maps", "Music", "Sounds", "Textures")
EXCLUDED_FONTS = {"ladderfonts.utx", "uwindowfonts.utx"}
EXCLUDED_SUFFIXES = {".exe", ".dll", ".dylib", ".app", ".iso", ".bin"}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def find_root(source: Path) -> Path:
    candidates = [source] + [p for p in source.rglob("*") if p.is_dir()]
    for candidate in candidates:
        if all((candidate / name).is_dir() for name in CONTENT_DIRS):
            return candidate
    raise SystemExit(f"No UT99 content root found below {source}")


def copy_content(root: Path, staging: Path) -> list[dict[str, object]]:
    manifest: list[dict[str, object]] = []
    for dirname in CONTENT_DIRS:
        for source in sorted((root / dirname).rglob("*")):
            if not source.is_file():
                continue
            if source.name.lower() in EXCLUDED_FONTS:
                continue
            if source.suffix.lower() in EXCLUDED_SUFFIXES:
                continue
            relative = Path(dirname) / source.relative_to(root / dirname)
            target = staging / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
            manifest.append({"path": relative.as_posix(), "size": target.stat().st_size, "sha256": sha256(target)})
    if not manifest:
        raise SystemExit("No content files found in Maps/Music/Sounds/Textures")
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--zip", action="store_true", dest="make_zip")
    args = parser.parse_args()
    source = args.source.expanduser().resolve()
    output = args.output.expanduser().resolve()
    if not source.exists():
        raise SystemExit(f"Source does not exist: {source}")
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="ut99-data-", dir=output.parent) as tmp:
        staging = Path(tmp) / "UT99Data"
        staging.mkdir()
        root = find_root(source)
        files = copy_content(root, staging)
        metadata = {"format": 1, "source_root_name": root.name, "files": files}
        (staging / "manifest.json").write_text(json.dumps(metadata, indent=2) + "\n")
        if output.exists():
            raise SystemExit(f"Refusing to overwrite existing output: {output}")
        staging.rename(output)
    if args.make_zip:
        archive = output.with_suffix(".zip")
        with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as stream:
            for path in sorted(output.rglob("*")):
                if path.is_file():
                    stream.write(path, path.relative_to(output).as_posix())
        print(f"Wrote {archive}")
    print(f"Prepared {len(metadata['files'])} content files at {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
