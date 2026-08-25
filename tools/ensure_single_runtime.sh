#!/bin/bash
set -euo pipefail
mode="${1:---check}"
list_project_processes() { ps -axo pid=,ppid=,command= | awk '/UnrealTournament|UT99|UT99Host/ && !/awk|ensure_single_runtime/ {print}'; }
if [[ "$mode" == "--clean" ]]; then
  while read -r pid _; do [[ -z "${pid:-}" ]] && continue; kill "$pid" 2>/dev/null || true; done < <(list_project_processes)
  xcrun simctl shutdown all >/dev/null 2>&1 || true
  sleep 1
fi
echo "Project-related processes:"
if ! list_project_processes; then echo "(none)"; fi
booted="$(xcrun simctl list devices 2>/dev/null | awk '/Booted/{count++} END{print count+0}')"
if (( booted > 1 )); then echo "ERROR: more than one simulator is booted ($booted)" >&2; exit 2; fi
echo "Booted simulators: $booted"
