#!/usr/bin/env bash
# check_architecture_parity.sh — fail when active docs/specs contain stale
# architecture identifiers (FastAPI, React/Vite, Tauri, Python sidecar, etc.)
# Excludes: lines that forbid the tech, German words matching patterns,
# and Flutter-native class names like WebviewWindow.
set -euo pipefail

SEARCH_DIRS=("docs" "openspec/specs")

violations=0
for dir in "${SEARCH_DIRS[@]}"; do
  [ -d "$dir" ] || continue
  # Match whole-word patterns to avoid false positives like "reactivated"
  while IFS= read -r line; do
    # Skip lines that forbid the technology
    if echo "$line" | grep -qiE '(shall not|not require|NOT.*Tauri|NOT.*Python|NOT.*webview)'; then
      continue
    fi
    # Skip German false positives (reaktiviert, etc.)
    if echo "$line" | grep -qiE 'reaktiv|beendet'; then
      continue
    fi
    # Skip Flutter-native class references (WebviewWindow is a real Flutter class)
    if echo "$line" | grep -qiE 'WebviewWindow'; then
      continue
    fi
    # Skip specs being superseded by an active delta spec in openspec/changes/
    if echo "$line" | grep -qE '^openspec/specs/desktop/'; then
      continue
    fi
    echo "STALE: $line"
    violations=$((violations + 1))
  done < <(grep -rniE '\bFastAPI\b|\bReact\b|\bVite\b|\bTailwind\b|\bTauri\b|Python sidecar|\bPyInstaller\b' "$dir" 2>/dev/null || true)
done

if [ "$violations" -gt 0 ]; then
  echo ""
  echo "Architecture parity check FAILED: $violations stale reference(s) found."
  exit 1
fi

echo "Architecture parity check passed."
exit 0
