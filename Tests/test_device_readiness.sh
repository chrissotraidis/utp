#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

set +e
output="$(./tools/run_ios_device.sh --check 2>&1)"
device_exit=$?
set -e

case "$device_exit" in
  0|3|4) ;;
  *)
    echo "unexpected device readiness exit: $device_exit" >&2
    echo "$output" >&2
    exit 1
    ;;
esac

grep -q '^device_readiness=' <<<"$output"
grep -Eq 'physical_ios_ipados_devices=[0-9]+' <<<"$output"

echo "UT99 physical-device readiness PASS outcome=$device_exit"
