#!/usr/bin/env bash
# One-time setup for developers. Installs xcbeautify, which scripts/build.sh requires.
# Safe to rerun: it does nothing when xcbeautify is already installed.
set -euo pipefail

if command -v xcbeautify >/dev/null 2>&1; then
  echo "xcbeautify already installed: $(xcbeautify --version)"
  exit 0
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required to install xcbeautify. Install it from https://brew.sh and rerun this script." >&2
  exit 1
fi

brew install xcbeautify
echo "xcbeautify installed: $(xcbeautify --version)"
