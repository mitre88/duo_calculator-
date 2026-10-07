#!/usr/bin/env bash
# Generates the Xcode project on a Mac (Xcode 27.1+) and builds the engine package.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "▶ Installing XcodeGen with Homebrew…"
  brew install xcodegen
fi

echo "▶ Generating App/DuoCalculator.xcodeproj"
xcodegen generate --spec App/project.yml --project App

echo "▶ Building and testing CalcEngine (SwiftPM)"
swift build --package-path Packages/CalcEngine
swift test  --package-path Packages/CalcEngine --parallel

cat <<MSG

✅ Done. Next steps:
   open App/DuoCalculator.xcodeproj
   • Choose the "iPhone Duo" simulator (Xcode 27.1 Device Hub) and run.
   • Use the Closed / Open / Laptop / Book / Tent buttons (⌥ shows the hinge-angle slider).
MSG
