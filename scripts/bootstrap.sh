#!/usr/bin/env bash
# One-time setup on the Mac: generates the Xcode project from project.yml.
# Usage:  ./scripts/bootstrap.sh            (then open AutoWhiteNoise.xcodeproj)
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "Installing XcodeGen with Homebrew…"
    brew install xcodegen
  else
    echo "XcodeGen is not installed and Homebrew is missing."
    echo "Install Homebrew from https://brew.sh, then run this script again."
    exit 1
  fi
fi

xcodegen generate
echo
echo "Generated AutoWhiteNoise.xcodeproj. Opening it…"
open AutoWhiteNoise.xcodeproj
