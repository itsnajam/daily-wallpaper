#!/bin/bash
# Install bingwall: copy the script, write and load the LaunchAgent, run once.
# Made by Najam · https://najam.dev
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABEL="dev.najam.bingwallpaper"
UID_NUM="$(id -u)"

BIN_DIR="$HOME/.local/bin"
TARGET="$BIN_DIR/bingwall"
AGENT_DIR="$HOME/Library/LaunchAgents"
PLIST="$AGENT_DIR/$LABEL.plist"
LOG_FILE="$HOME/Library/Logs/BingWallpaper.log"
STORE_DIR="$HOME/Library/Application Support/BingWallpaper"
CONFIG="$STORE_DIR/settings.conf"

if [ ! -f "$HERE/bingwall.sh" ]; then
  echo "Could not find bingwall.sh next to install.sh." >&2
  exit 1
fi

mkdir -p "$BIN_DIR" "$AGENT_DIR" "$STORE_DIR" "$(dirname "$LOG_FILE")"
cp "$HERE/bingwall.sh" "$TARGET"
chmod +x "$TARGET"

# Honor a previously saved interval; default to 12 hours.
BW_EVERY="12h"
[ -f "$CONFIG" ] && . "$CONFIG"
if [ "$BW_EVERY" = "manual" ]; then
  INTERVAL_XML=""
  RUN_AT_LOAD="<false/>"
else
  HOURS="${BW_EVERY%h}"
  INTERVAL_XML="    <key>StartInterval</key>
    <integer>$((HOURS * 3600))</integer>"
  RUN_AT_LOAD="<true/>"
fi

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$TARGET</string>
    </array>
$INTERVAL_XML
    <key>RunAtLoad</key>
    $RUN_AT_LOAD
    <key>StandardOutPath</key>
    <string>$LOG_FILE</string>
    <key>StandardErrorPath</key>
    <string>$LOG_FILE</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin</string>
    </dict>
</dict>
</plist>
EOF

# Reload cleanly, then start it. RunAtLoad fires one run; we also run once in
# the foreground so the wallpaper is set before this script returns.
launchctl bootout "gui/$UID_NUM/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$UID_NUM" "$PLIST"
"$TARGET" || true

echo "Bing Wallpaper installed. Made by Najam · https://najam.dev"

# Expose the store under ~/Pictures (System Settings' picker hides ~/Library).
mkdir -p "$HOME/Pictures"
[ -e "$HOME/Pictures/Bing Wallpaper" ] || ln -s "$STORE_DIR" "$HOME/Pictures/Bing Wallpaper"

# The lock screen follows automatically once it is a normal photo. Only an Aerial
# wallpaper needs a one-time pick.
PROVIDER="$(python3 - <<'PY'
import plistlib, os
p = os.path.expanduser("~/Library/Application Support/com.apple.wallpaper/Store/Index.plist")
try:
    r = plistlib.load(open(p, "rb"))
    print(r["SystemDefault"]["Desktop"]["Content"]["Choices"][0].get("Provider", ""))
except Exception:
    print("")
PY
)"
if [ "$PROVIDER" != "com.apple.wallpaper.choice.image" ]; then
  echo "Lock screen tip: pick the current photo under Your Photos (Pictures -> Bing Wallpaper) and turn on Show on all Spaces, once. bingwall keeps it updated after that."
fi