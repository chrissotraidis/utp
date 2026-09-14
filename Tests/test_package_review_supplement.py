import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("supplement", ROOT / "tools/package_review_supplement.py")
supplement = importlib.util.module_from_spec(spec)
spec.loader.exec_module(supplement)


class PackageSupplementTests(unittest.TestCase):
    def test_inventory_notices_and_no_binary_copy(self):
        with tempfile.TemporaryDirectory() as directory:
            ipa, out = Path(directory) / "app.ipa", Path(directory) / "review.zip"
            font = b"fixture font"
            with zipfile.ZipFile(ipa, "w") as archive:
                archive.writestr("Payload/UT99Apple.app/UT99FontSupport/Fixture.ttf", font)
                archive.writestr("Payload/UT99Apple.app/Frameworks/Engine.dylib", b"private binary")
            before = ipa.read_bytes()
            with patch.dict(supplement.FONT_HASHES, {"Fixture.ttf": hashlib.sha256(font).hexdigest()}, clear=True):
                supplement.package(ipa, out, ROOT, "fixture-commit")
            self.assertEqual(before, ipa.read_bytes())
            with zipfile.ZipFile(out) as archive:
                self.assertEqual(set(archive.namelist()), {"README.md", "manifest.json", *supplement.NOTICE_FILES})
                manifest = json.loads(archive.read("manifest.json"))
                self.assertEqual(manifest["ipa_sha256"], hashlib.sha256(before).hexdigest())
                self.assertEqual(len(manifest["members"]), 2)
                for name in supplement.NOTICE_FILES:
                    self.assertEqual(archive.read(name), (ROOT / name).read_bytes())

    def test_changed_font_does_not_replace_existing_supplement(self):
        with tempfile.TemporaryDirectory() as directory:
            ipa, out = Path(directory) / "app.ipa", Path(directory) / "review.zip"
            out.write_bytes(b"existing")
            with zipfile.ZipFile(ipa, "w") as archive:
                archive.writestr("Payload/UT99Apple.app/UT99FontSupport/Tinos-Regular.ttf", b"changed")
            with self.assertRaisesRegex(ValueError, "font inventory changed"):
                supplement.package(ipa, out, ROOT, "fixture")
            self.assertEqual(out.read_bytes(), b"existing")

    def test_unsafe_member_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            ipa = Path(directory) / "app.ipa"
            with zipfile.ZipFile(ipa, "w") as archive:
                archive.writestr("../private.txt", b"secret")
            with self.assertRaisesRegex(ValueError, "unsafe"):
                supplement.package(ipa, Path(directory) / "out.zip", ROOT, "fixture")
