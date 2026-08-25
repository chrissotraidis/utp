#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/ut99-data-transaction.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT

xcrun swiftc -parse-as-library \
  "$root/Sources/UT99Host/UT99DataImportTransaction.swift" \
  "$root/Sources/UT99Host/UT99DataImporter.swift" \
  "$root/Tests/DataImportTransactionTests.swift" \
  -o "$test_root/test_data_import_transaction"
"$test_root/test_data_import_transaction"
