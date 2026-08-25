#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

ensure_git_checkout() {
  local directory="$1"
  local url="$2"
  local commit="$3"
  local license="$4"

  if [[ -d "$directory/.git" ]]; then
    local actual
    actual="$(git -C "$directory" rev-parse HEAD)"
    if [[ "$actual" != "$commit" ]]; then
      echo "bootstrap=blocked dependency=$directory expected=$commit actual=$actual" >&2
      exit 2
    fi
    echo "bootstrap=present dependency=$directory commit=$actual"
    return
  fi

  echo "bootstrap=install dependency=$directory reason=required_ios_build_input url=$url commit=$commit license=$license"
  local staging
  staging="$(mktemp -d "${TMPDIR:-/tmp}/ut99-bootstrap.XXXXXX")"
  trap 'rm -rf "$staging"' RETURN
  git clone --filter=blob:none --no-checkout "$url" "$staging/source"
  git -C "$staging/source" checkout --detach "$commit"
  mkdir -p "$(dirname "$directory")"
  mv "$staging/source" "$directory"
  rm -rf "$staging"
  trap - RETURN
}

ensure_download() {
  local output="$1"
  local url="$2"
  local expected_sha="$3"
  local purpose="$4"
  local license="$5"

  if [[ -f "$output" ]]; then
    local actual
    actual="$(shasum -a 256 "$output" | awk '{print $1}')"
    if [[ "$actual" != "$expected_sha" ]]; then
      echo "bootstrap=blocked input=$output expected_sha256=$expected_sha actual_sha256=$actual" >&2
      exit 2
    fi
    echo "bootstrap=present input=$output sha256=$actual"
    return
  fi

  echo "bootstrap=download input=$output reason=$purpose url=$url sha256=$expected_sha license=$license"
  mkdir -p "$(dirname "$output")"
  local partial="${output}.partial"
  curl -fL --retry 3 --output "$partial" "$url"
  local actual
  actual="$(shasum -a 256 "$partial" | awk '{print $1}')"
  if [[ "$actual" != "$expected_sha" ]]; then
    rm -f "$partial"
    echo "bootstrap=failed input=$output reason=sha256_mismatch expected=$expected_sha actual=$actual" >&2
    exit 1
  fi
  mv "$partial" "$output"
}

ensure_download \
  "ref/OldUnreal/OldUnreal-UTPatch469e-macOS.dmg" \
  "https://github.com/OldUnreal/UnrealTournamentPatches/releases/download/v469e/OldUnreal-UTPatch469e-macOS.dmg" \
  "b6b3a1f462e4b702df0eecf90d663ef1f847cc36aadca1ec6dd35278d091fa0d" \
  "official_v469e_macos_reference" \
  "upstream_release_terms"

ensure_git_checkout "ref/SDL2" "https://github.com/libsdl-org/SDL.git" "5d249570393f7a37e037abf22cd6012a4cc56a71" "zlib"
ensure_git_checkout "ref/OpenAL-Soft" "https://github.com/kcat/openal-soft.git" "2dc741b54a49fc6a7716afd1504ca1056cff7db4" "LGPL-2.0-or-later"
ensure_git_checkout "ref/libsndfile" "https://github.com/libsndfile/libsndfile.git" "7ff854d1e0bd9a751a9ff52ed980c62afced91fe" "LGPL-2.1-or-later"
ensure_git_checkout "ref/libxmp" "https://github.com/libxmp/libxmp.git" "a13276d27feabcf9ee4f982913f718ee05a65cb7" "MIT-like"

mpg_archive="ref/mpg123-1.33.6.tar.bz2"
ensure_download "$mpg_archive" \
  "https://www.mpg123.de/download/mpg123-1.33.6.tar.bz2" \
  "929a7c18ba662b8927aed4de229ad9ae8ab2b4806dd0f30b90113eb1b4e2195a" \
  "required_ios_audio_decoder_source" \
  "LGPL-2.1-or-later"

if [[ ! -d ref/mpg123 ]]; then
  echo "bootstrap=install dependency=ref/mpg123 reason=required_ios_audio_decoder_source archive=$mpg_archive"
  staging="$(mktemp -d "${TMPDIR:-/tmp}/ut99-mpg123.XXXXXX")"
  tar -xjf "$mpg_archive" -C "$staging"
  mv "$staging/mpg123-1.33.6" ref/mpg123
  rmdir "$staging"
fi

echo "bootstrap=PASS lock=third_party/deps.lock.json"
