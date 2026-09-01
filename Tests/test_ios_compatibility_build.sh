#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

bash -n tools/build_ios_dependencies.sh tools/build_ios_frucore_metallib.sh \
  tools/package_local_ipa.sh tools/run_ios_device.sh
python3 -m py_compile tools/prepare_ios_engine_artifact.py tools/verify_ios_minimum_versions.py

rg -Fq 'UT99_IOS_MIN ?= 17.0' Makefile
rg -Fq 'ios15-experimental-package:' Makefile
rg -Fq 'UT99_IOS_MIN=15.0 UT99_PACKAGE_MODE=public' Makefile
rg -Fq 'minimum_os="${UT99_IOS_MIN:-17.0}"' tools/build_ios_dependencies.sh
rg -Fq 'minimum_os="${UT99_IOS_MIN:-17.0}"' tools/build_ios_frucore_metallib.sh
rg -Fq 'IPHONEOS_DEPLOYMENT_TARGET="$minimum_os"' tools/package_local_ipa.sh
rg -Fq 'minimum_ios_version:$minimum_ios_version' tools/package_local_ipa.sh
rg -Fq 'verify_ios_minimum_versions.py' tools/verify_ios_package.sh
rg -Fq 'if #available(iOS 16.0, *)' Sources/UT99Host/GameViewController.swift
rg -Fq 'UIViewController.attemptRotationToDeviceOrientation()' Sources/UT99Host/GameViewController.swift

python3 - <<'PY'
from tools.verify_ios_minimum_versions import version_tuple

assert version_tuple("15.0") == (15, 0, 0)
assert version_tuple("15.5.1") == (15, 5, 1)
assert version_tuple("17.0") > version_tuple("15.0")
PY

echo "iOS compatibility build PASS stableDefault=17.0 experimentalMinimum=15.0"
