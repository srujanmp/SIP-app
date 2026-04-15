#!/bin/bash
# Utility script — run this inside container if device isn't showing up

echo "→ Killing existing ADB server..."
adb kill-server

echo "→ Starting fresh ADB server..."
adb start-server

echo "→ Connected devices:"
adb devices

# Check if any device is connected
if adb devices | grep -q "device$"; then
  echo ""
  echo "✓ Device found and ready!"
else
  echo ""
  echo "✗ No device found. Checklist:"
  echo "  1. USB cable is plugged in"
  echo "  2. USB Debugging is ON (Developer Options)"
  echo "  3. Phone screen is unlocked"
  echo "  4. Tapped 'Allow' on the USB debugging popup"
  echo "  5. On HOST run: adb devices (must show 'device' there first)"
fi