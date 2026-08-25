#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

bash -n tools/package_local_ipa.sh
rg -q 'mode="\$\{UT99_PACKAGE_MODE:-signed\}"' tools/package_local_ipa.sh
rg -q 'signed|public|diagnostic' tools/package_local_ipa.sh
rg -q 'reason=set_DEVELOPMENT_TEAM' tools/package_local_ipa.sh
rg -q 'UT99_PACKAGE_MODE=diagnostic make package-local' tools/package_local_ipa.sh
rg -q 'make ios-engine-real-artifact' tools/package_local_ipa.sh
rg -q 'CODE_SIGNING_ALLOWED=YES' tools/package_local_ipa.sh
rg -q 'CODE_SIGNING_ALLOWED=NO' tools/package_local_ipa.sh
[[ "$(rg -c 'clean build' tools/package_local_ipa.sh)" == "2" ]]
rg -q 'verify_ios_package\.sh' tools/package_local_ipa.sh
rg -q 'reason=user_game_data_embedded' tools/package_local_ipa.sh
rg -q 'embedded\.mobileprovision' tools/package_local_ipa.sh
rg -q 'Payload/UT99Apple\.app' tools/package_local_ipa.sh
rg -q 'UTP-signed\.ipa' tools/package_local_ipa.sh
rg -q 'UTP-diagnostic-ad-hoc\.ipa' tools/package_local_ipa.sh
rg -Fq 'UTP-${release_version}-unsigned.ipa' tools/package_local_ipa.sh
rg -q 're_signable:\$re_signable' tools/package_local_ipa.sh
rg -q 'reason=signing_metadata_archived' tools/package_local_ipa.sh
rg -q 'codesign --remove-signature' tools/package_local_ipa.sh
rg -q 'reason=embedded_code_signature_archived' tools/package_local_ipa.sh
rg -q 'reason=development_team_identifier_archived' tools/package_local_ipa.sh
rg -q 'contains_user_game_data:false' tools/package_local_ipa.sh
rg -q 'runtime_jit_required:false' tools/package_local_ipa.sh
rg -q 'zip -X -q -r' tools/package_local_ipa.sh
rg -q 'reason=mac_metadata_archived' tools/package_local_ipa.sh
rg -q 'unavailable iOS AudioUnit runtime dependency' tools/verify_ios_package.sh
rg -q 'AudioToolbox' tools/verify_ios_package.sh
rg -q 'nested runtime data directory found' tools/verify_ios_package.sh
rg -q 'missing embedded FruCoRe shader' tools/verify_ios_package.sh
if rg -q 'cp -R build/UT99Data build/.*/UT99Data' Makefile; then
  echo "package targets still use non-idempotent UT99Data directory copying" >&2
  exit 1
fi

set +e
output="$(env -u DEVELOPMENT_TEAM -u UT99_PACKAGE_MODE ./tools/package_local_ipa.sh 2>&1)"
status=$?
set -e
[[ "$status" == "4" ]]
grep -q 'package_local=blocked reason=set_DEVELOPMENT_TEAM mode=signed' <<<"$output"

rg -q '^package-local:' Makefile

echo "UT99 local IPA packaging PASS signedPreflight=true diagnosticMode=true noGameData=true"
