#!/bin/bash
# Uninstall bingwall: stop and remove the agent, the script, and the images.
# Made by Najam · https://najam.dev
set -uo pipefail

LABEL="dev.najam.bingwallpaper"
UID_NUM="$(id -u)"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
TARGET="$HOME/.local/bin/bingwall"
STORE_DIR="$HOME/Library/Application Support/BingWallpaper"
CACHE_DIR="$HOME/Library/Caches/BingWallpaper"

launchctl bootout "gui/$UID_NUM/$LABEL" 2>/dev/null || true
rm -f "$PLIST"
rm -f "$TARGET"
rm -rf "$STORE_DIR"
rm -rf "$CACHE_DIR"

echo "Bing Wallpaper uninstalled. The log was left at ~/Library/Logs/BingWallpaper.log."
echo "Pick a new wallpaper in System Settings if you want to replace the last image."
echo "Made by Najam · https://najam.dev"