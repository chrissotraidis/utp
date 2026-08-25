#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

output="$(./tools/doctor.sh)"
for field in \
  host xcode developer_dir sdk brew python uv required_tools disk \
  signing_identity_count project_development_team_count device_signing_ready \
  physical_ios_ipados_devices booted_simulators prd goal_loop ref_ectopad \
  source_mirror_ectopad ref_v469e game_data_ref game_data_pack git; do
  if ! grep -q "^${field}=" <<<"$output"; then
    echo "doctor report missing field: $field" >&2
    exit 1
  fi
done

grep -q '^prd=present$' <<<"$output"
grep -q '^goal_loop=present$' <<<"$output"
grep -Eq '^device_signing_ready=(yes|no)$' <<<"$output"
grep -Eq '^physical_ios_ipados_devices=([0-9]+|unavailable)$' <<<"$output"
grep -q '^required_tools=.*cmake:.*ninja:.*jq:.*codesign:.*clang:' <<<"$output"

echo "UT99 doctor report PASS"
