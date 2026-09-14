#!/usr/bin/env python3
"""Package verified font notices, pinned upstream notices, and an inventory without copying app/game bytes."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import tempfile
import zipfile

FONT_HASHES = {
    "Tinos-Regular.ttf": "ff4deb395ff2426bbd08db74cb005b22326175df00f0a156b87e6d2aef1ef508",
    "CourierPrime.ttf": "6cc9525b1334047445cba53f323e810331acfdf59f18f4008397d13137737b91",
    "OpenSans-Regular.ttf": "037236ed4bf58a85f67074c165d308260fd6be01c86d7df4e79ea16eb273f8c5",
}
NOTICE_FILES = (
    "third_party/notices/README.md",
    "third_party/notices/Apache-2.0.txt",
    "third_party/notices/CourierPrime-OFL-1.1.txt",
    'third_party/notices/libraries/README.md',
    'third_party/notices/libraries/provenance.json',
    'third_party/notices/OldUnreal-v469e/README.md',
    'third_party/notices/OldUnreal-v469e/LICENSE.md',
    'third_party/notices/libraries/SDL2/LICENSE.txt',
    'third_party/notices/libraries/OpenAL-Soft/COPYING',
    'third_party/notices/libraries/OpenAL-Soft/LICENSE-pffft',
    'third_party/notices/libraries/OpenAL-Soft/LICENSE.Apache-2.0.txt',
    'third_party/notices/libraries/OpenAL-Soft/LICENSE.BSD-3-Clause.txt',
    'third_party/notices/libraries/OpenAL-Soft/fmt-11.2.0/LICENSE',
    'third_party/notices/libraries/OpenAL-Soft/gsl/LICENSE',
    'third_party/notices/libraries/mpg123/COPYING',
    'third_party/notices/libraries/mpg123/AUTHORS',
    'third_party/notices/libraries/libsndfile/COPYING',
    'third_party/notices/libraries/libsndfile/src/ALAC/LICENSE',
    'third_party/notices/libraries/libxmp/docs/COPYING',
    'third_party/notices/libraries/libxmp/src/loaders/prowizard/LICENSE.txt',
)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def package(ipa, output, root, source_commit):
    if ipa.resolve() == output.resolve():
        raise ValueError("supplement must not replace the IPA")
    records = []
    seen = set()
    fonts = {}
    with zipfile.ZipFile(ipa) as archive:
        for member in archive.infolist():
            name = member.filename
            path = PurePosixPath(name)
            if path.is_absolute() or ".." in path.parts or "\\" in name or name in seen:
                raise ValueError("unsafe or duplicate archive member")
            seen.add(name)
            if member.is_dir():
                continue
            data = archive.read(member)
            digest = sha256(data)
            records.append({"path": name, "bytes": len(data), "sha256": digest})
            prefix = "Payload/UT99Apple.app/UT99FontSupport/"
            if name.startswith(prefix) and name.endswith(".ttf"):
                fonts[name[len(prefix):]] = digest
    if fonts != FONT_HASHES:
        raise ValueError("font inventory changed; verify terms and update notices before packaging")
    notices = {name: (root / name).read_bytes() for name in NOTICE_FILES}
    manifest = {
        "schema_version": 1,
        "ipa_sha256": sha256(ipa.read_bytes()),
        "ipa_bytes": ipa.stat().st_size,
        "review_source_commit": source_commit,
        "scope": "Archive inventory, verified font notices and pinned upstream notices; not complete Corresponding Source or rights clearance.",
        "members": sorted(records, key=lambda item: item["path"]),
        "notice_sha256": {name: sha256(data) for name, data in notices.items()},
        "remaining_review": [
            "Runtime and FMOD input terms and any separate redistribution permission",
            "Exact library/source matching and required source/relinking delivery",
            "Other dependency notices and additional upstream font NOTICE material",
        ],
    }
    readme = """# UTP package review supplement

This companion belongs to the IPA identified by the SHA-256 in manifest.json.
It contains an exact archive inventory, notices for the three verified
font versions, and upstream notice copies from pinned library/OldUnreal inputs.
The OldUnreal collection covers multiple platforms and does not establish that
every listed component ships in this app. It contains no executable, font binary, game data, credentials,
or signing material. Member hashes identify contents; they do not license them.

This is partial review material, not a complete license/source supplement or a
legal clearance statement. The manifest lists the remaining checks. Publish it
alongside its matching IPA; do not reuse it for a different build.

Font notices: third_party/notices/README.md.
Source repository: https://github.com/chrissotraidis/utp
The recorded source commit identifies the packaging checkout; notice_sha256
identifies the exact notice text included even if local edits were present.
"""
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=output.parent, suffix=".zip", delete=False) as handle:
        temporary = Path(handle.name)
    try:
        with zipfile.ZipFile(temporary, "w", zipfile.ZIP_DEFLATED) as archive:
            archive.writestr("README.md", readme)
            archive.writestr("manifest.json", json.dumps(manifest, indent=2) + "\n")
            for name, data in notices.items():
                archive.writestr(name, data)
        temporary.replace(output)
    finally:
        temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ipa", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--source-commit", required=True)
    args = parser.parse_args()
    package(args.ipa, args.output, Path(__file__).resolve().parent.parent, args.source_commit)
    print(f"package_review_supplement={args.output}")
