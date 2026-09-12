#!/usr/bin/env bash
set -euo pipefail

required_packages=(gtk+-3.0 keybinder-3.0 appindicator3-0.1)
missing=()
for package in "${required_packages[@]}"; do
  if ! pkg-config --exists "$package"; then
    missing+=("$package")
  fi
done

if ((${#missing[@]} > 0)); then
  printf 'Missing Linux development packages: %s\n' "${missing[*]}" >&2
  printf 'Install the packages required by hotkey_manager_linux and system_tray, then retry.\n' >&2
  exit 1
fi

fvm flutter build linux --debug
printf 'Built build/linux/x64/debug/bundle/openaccounting\n'
