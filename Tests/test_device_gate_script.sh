#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

bash -n tools/verify_ios_device.sh
rg -q -- '-UT99G2SmokeTest' tools/verify_ios_device.sh
rg -q -- '-UT99G2RunID=' tools/verify_ios_device.sh
rg -q 'runID=\$g2_run_id' tools/verify_ios_device.sh
rg -q 'UT99-host-metal-smoke\.log' tools/verify_ios_device.sh
rg -q 'UT99-g2-smoke\.log' tools/verify_ios_device.sh
rg -q 'UT99-import-transaction-smoke\.log' tools/verify_ios_device.sh
rg -q 'UT99-diagnostics-smoke\.zip' tools/verify_ios_device.sh
rg -q 'unzip -t' tools/verify_ios_device.sh
rg -q 'classification=AUTOMATED_PARTIAL' tools/verify_ios_device.sh
rg -q 'manual_required=' tools/verify_ios_device.sh

echo "UT99 physical G2 gate script PASS"
