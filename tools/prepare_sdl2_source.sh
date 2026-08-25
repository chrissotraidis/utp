#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

source_dir="$root/ref/SDL2"
output_dir="$root/build/sources/SDL2-UT99"
patch_file="$root/third_party/patches/sdl2-ut99-ios.patch"
expected_commit="5d249570393f7a37e037abf22cd6012a4cc56a71"

[[ -d "$source_dir/.git" ]] || { echo "sdl_source=blocked reason=missing_ref run='make bootstrap'" >&2; exit 2; }
[[ "$(git -C "$source_dir" rev-parse HEAD)" == "$expected_commit" ]] || {
  echo "sdl_source=blocked reason=unexpected_ref_commit" >&2
  exit 2
}
[[ -z "$(git -C "$source_dir" status --short)" ]] || {
  echo "sdl_source=blocked reason=dirty_ref path=$source_dir" >&2
  exit 2
}
[[ -f "$patch_file" ]] || { echo "sdl_source=blocked reason=missing_patch" >&2; exit 2; }

patch_sha="$(shasum -a 256 "$patch_file" | awk '{print $1}')"
stamp="$output_dir/.ut99-sdl-patch-sha256"
if [[ -f "$stamp" ]] && [[ "$(<"$stamp")" == "$patch_sha" ]]; then
  echo "sdl_source=PASS reused=true patch_sha256=$patch_sha"
  exit 0
fi

if [[ -e "$output_dir" ]]; then
  quarantine="$(mktemp -d /tmp/ut99-stale-sdl-source.XXXXXX)"
  mv "$output_dir" "$quarantine/SDL2-UT99"
  echo "sdl_source=quarantined path=$quarantine/SDL2-UT99"
fi

staging="$(mktemp -d "$root/build/sources/.SDL2-UT99.XXXXXX")"
cleanup() { rm -rf "$staging"; }
trap cleanup EXIT
mkdir -p "$staging/source"
rsync -a --exclude '.git/' "$source_dir/" "$staging/source/"
patch -s -d "$staging/source" -p1 < "$patch_file"
printf '%s\n' "$patch_sha" > "$staging/source/.ut99-sdl-patch-sha256"
mv "$staging/source" "$output_dir"
rmdir "$staging"
trap - EXIT

echo "sdl_source=PASS reused=false patch_sha256=$patch_sha"
