#!/usr/bin/env bash
set -euo pipefail

if pgrep -x asterisk >/dev/null 2>&1; then
  echo "[devcontainer] Asterisk already running"
  exit 0
fi

ASTERISK_CONF="asterisk.conf"
if [ -f "/etc/asterisk/asterisk.conf" ]; then
  ASTERISK_CONF="/etc/asterisk/asterisk.conf"
fi

ASTERISK_USER="root"
ASTERISK_GROUP="root"
if id -u asterisk >/dev/null 2>&1; then
  ASTERISK_USER="asterisk"
  ASTERISK_GROUP="asterisk"
fi

echo "[devcontainer] Starting Asterisk in background..."
asterisk -C "$ASTERISK_CONF" -f -U "$ASTERISK_USER" -G "$ASTERISK_GROUP" \
  >/tmp/asterisk.log 2>&1 &

sleep 1
if ! asterisk -rx "core show uptime" >/dev/null 2>&1; then
  echo "[devcontainer] Failed to start Asterisk. See /tmp/asterisk.log"
  exit 1
fi

echo "[devcontainer] Asterisk started"