#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

python3 tools/write_audit_json.py --self-test
rg -q 'recursive file\(1\) Mach-O identification' tools/write_audit_json.py
rg -q 'all_shipping_images_have_arm64' tools/write_audit_json.py
rg -q 'undefined_symbols' tools/write_audit_json.py
rg -q 'objective_c_selectors' tools/write_audit_json.py
rg -q 'has_writable_executable_segment' tools/write_audit_json.py
rg -q 'developer_identity_redacted' tools/write_audit_json.py

if [[ -f build/audit/469e-audit.json ]]; then
  python3 - <<'PY'
import json
from pathlib import Path

audit = json.loads(Path("build/audit/469e-audit.json").read_text())
assert audit["schema_version"] == 2
assert audit["discovery"]["native_image_count"] == len(audit["native_images"])
assert audit["discovery"]["native_image_count"] >= 8
assert all(image["has_arm64"] for image in audit["native_images"])
assert all("arm64" in image and "dependencies" in image["arm64"] for image in audit["native_images"])
assert audit["g1_evaluation"]["result"] in {"PASS", "FAIL"}
print("UT99 generated complete Mach-O audit schema PASS images=%d gate=%s" % (
    len(audit["native_images"]), audit["g1_evaluation"]["result"]
))
PY
fi
