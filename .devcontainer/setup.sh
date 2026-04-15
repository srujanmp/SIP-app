#!/bin/bash
set -e

echo "──────────────────────────────────────"
echo "  Dev Container Post-Create Setup"
echo "──────────────────────────────────────"

# ── Install project deps ──────────────────────────────────────
if [ -f "package.json" ]; then
  echo "→ Installing Node deps..."
  npm install
fi

# ── Flutter deps ──────────────────────────────────────────────
if [ -f "pubspec.yaml" ]; then
  echo "→ Running flutter pub get..."
  flutter pub get
fi

# ── Verify ADB can see host's server ─────────────────────────
echo "→ Checking ADB connection..."
adb version
echo "→ Connected devices:"
adb devices

# ── Print SDK info ────────────────────────────────────────────
echo "→ Installed Android SDK components:"
sdkmanager --list_installed

echo ""
echo "✓ Setup complete!"
echo "  Phone connected via USB cable should already show above."
echo "  If not, run: adb kill-server && adb start-server && adb devices"