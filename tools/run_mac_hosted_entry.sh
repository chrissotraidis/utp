#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/build/macos-hosted"
mkdir -p "$out/evidence"
cd "$root/build/macos-baseline/UnrealTournament.app/Contents/MacOS"
"$out/HostedLoader.app/Contents/MacOS/hosted-loader" "$out/UnrealTournament.dylib" --invoke > "$out/evidence/entry.log" 2>&1 &
pid=$!
sleep 12
screencapture -x "$out/evidence/entry-screen.png" 2>/dev/null || true
kill -TERM "$pid" 2>/dev/null || true
sleep 1
kill -KILL "$pid" 2>/dev/null || true
wait "$pid" 2>/dev/null || true
cat "$out/evidence/entry.log"
if ! rg -q 'invoking original LC_MAIN entry|Unreal engine initialized|Game engine initialized' "$out/evidence/entry.log"; then
  echo "Hosted entry did not reach distinctive engine startup" >&2
  exit 1
fi
