import json
import tempfile
import unittest
from pathlib import Path
from subprocess import run


class PrepareDataTests(unittest.TestCase):
    def test_copies_content_and_excludes_desktop_inputs(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "source"
            out = Path(tmp) / "out"
            for name in ("Maps", "Music", "Sounds", "Textures"):
                (root / name).mkdir(parents=True)
            (root / "Maps" / "DM-Test.unr").write_bytes(b"map")
            (root / "Textures" / "LadderFonts.utx").write_bytes(b"old")
            (root / "System").mkdir()
            (root / "System" / "UnrealTournament").write_bytes(b"binary")
            result = run(["python3", "tools/prepare_ut99_data.py", "--source", str(root), "--output", str(out)], check=True, capture_output=True, text=True)
            self.assertIn("Prepared 1 content files", result.stdout)
            manifest = json.loads((out / "manifest.json").read_text())
            self.assertEqual([item["path"] for item in manifest["files"]], ["Maps/DM-Test.unr"])


if __name__ == "__main__":
    unittest.main()
