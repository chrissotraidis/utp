#!/usr/bin/env bash
# Fast source-publication gate. It never reads ignored local inputs.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail() {
    echo "Public repository check failed: $*" >&2
    exit 1
}

current_files="$(git ls-files --cached --others --exclude-standard | sort -u)"

private_roots="$(printf '%s\n' "$current_files" |
    grep -E '^(build|local|ref)/' || true)"
if [ -n "$private_roots" ]; then
    printf '%s\n' "$private_roots" >&2
    fail "build/, local/, or ref/ material is publishable"
fi

forbidden_extensions='\.(app|dmg|iso|img|ipa|xcarchive|mobileprovision|provisionprofile|p12|p8|pem|key|cer|zip|7z|rar|tar|tgz|tbz2|u|unr|utx|umx|uax|uz|dll|dylib|so|a)(/|$)'
forbidden_current="$(printf '%s\n' "$current_files" |
    grep -Ei "$forbidden_extensions|(^|/)[^/]+\.app/" || true)"
if [ -n "$forbidden_current" ]; then
    printf '%s\n' "$forbidden_current" >&2
    fail "an archive, app, game package, native binary, or signing file is publishable"
fi

history_paths="$(git rev-list --objects --all |
    awk 'NF > 1 { sub(/^[^ ]+ /, ""); print }')"
forbidden_history="$(printf '%s\n' "$history_paths" |
    grep -Ei '^(build|local|ref)/|(^|/)[^/]+\.app/|'"$forbidden_extensions" || true)"
if [ -n "$forbidden_history" ]; then
    printf '%s\n' "$forbidden_history" >&2
    fail "a prohibited artifact path exists in Git history"
fi

while IFS= read -r file; do
    [ -f "$file" ] || continue
    size="$(wc -c < "$file")"
    if [ "$size" -gt 5242880 ]; then
        echo "$file ($size bytes)" >&2
        fail "a publishable file exceeds the 5 MiB review limit"
    fi
done < <(printf '%s\n' "$current_files")

credential_pattern='(-----BEGIN [A-Z ]*PRIVATE KEY-----|github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{20,})'
credential_hits=""
local_path_hits=""
team_hits=""

while IFS= read -r file; do
    [ -f "$file" ] || continue
    [ "$file" = "Tests/DiagnosticsArchiveTests.swift" ] && continue

    matches="$(grep -nEI "$credential_pattern" "$file" 2>/dev/null || true)"
    if [ -n "$matches" ]; then
        credential_hits="${credential_hits}${file}:${matches}"$'\n'
    fi

    if [ "$file" != "Sources/UT99Host/UT99DiagnosticsArchive.swift" ] &&
       [ "$file" != "tools/check_public_repo.sh" ]; then
        matches="$(grep -nE '(/Users/[^/[:space:]]+/|/home/[^/[:space:]]+/|/var/folders/[^/[:space:]]+/|/private/var/folders/[^/[:space:]]+/)' "$file" 2>/dev/null || true)"
        if [ -n "$matches" ]; then
            local_path_hits="${local_path_hits}${file}:${matches}"$'\n'
        fi
    fi

    matches="$(grep -nE 'DEVELOPMENT_TEAM[=:[:space:]]+[A-Z0-9]{10}([^A-Z0-9]|$)' "$file" 2>/dev/null |
        grep -v 'YOURTEAMID' || true)"
    if [ -n "$matches" ]; then
        team_hits="${team_hits}${file}:${matches}"$'\n'
    fi
done < <(printf '%s\n' "$current_files")

if [ -n "$credential_hits" ]; then
    printf '%s' "$credential_hits" >&2
    fail "a likely credential or private key exists in the publishable tree"
fi
if [ -n "$local_path_hits" ]; then
    printf '%s' "$local_path_hits" >&2
    fail "a machine-specific home or temporary path exists in the publishable tree"
fi
if [ -n "$team_hits" ]; then
    printf '%s' "$team_hits" >&2
    fail "a concrete Apple development team identifier exists in the publishable tree"
fi

bash -n tools/*.sh Tests/*.sh
for script in tools/*.sh Tests/*.sh; do
    [ -x "$script" ] || fail "$script is not executable"
done

python3 - "$ROOT" <<'PY'
import json
import pathlib
import re
import subprocess
import sys
import urllib.parse

root = pathlib.Path(sys.argv[1])
markdown = subprocess.check_output(
    ["git", "ls-files", "--cached", "--others", "--exclude-standard", "*.md"],
    cwd=root,
    text=True,
).splitlines()
missing = []
patterns = [
    re.compile(r"!?\[[^\]]*\]\(([^)\s]+)"),
    re.compile(r'<(?:img|a)\b[^>]+(?:src|href)="([^"]+)"', re.IGNORECASE),
]

for relative in markdown:
    document = root / relative
    text = document.read_text(encoding="utf-8")
    for pattern in patterns:
        for raw_target in pattern.findall(text):
            target = raw_target.strip("<>")
            if target.startswith(("#", "/", "http://", "https://", "mailto:")):
                continue
            target = urllib.parse.unquote(target.split("#", 1)[0].split("?", 1)[0])
            # RESULT ledgers intentionally link to ignored raw screenshots and
            # logs that must not be published with the source snapshot.
            if relative.startswith("docs/evidence/") and relative.endswith("/RESULT.md"):
                continue
            if target and not (document.parent / target).exists():
                missing.append(f"{relative}: {raw_target}")

with (root / "third_party/deps.lock.json").open(encoding="utf-8") as handle:
    dependencies = json.load(handle)
if not isinstance(dependencies, dict):
    raise SystemExit("third_party/deps.lock.json must contain a JSON object")

if missing:
    print("Missing local Markdown targets:", file=sys.stderr)
    print("\n".join(missing), file=sys.stderr)
    raise SystemExit(1)
PY

git diff --check
git fsck --full --strict --no-dangling

echo "Public repository checks passed."
