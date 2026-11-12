#!/bin/bash
# bingwall - set a fresh Bing photo as the macOS wallpaper, once per run.
# Made by Najam · https://najam.dev
#
# One run: fetch Bing's public image feed from several markets, keep only the
# wallpaper types you picked, download the newest match that is not already the
# wallpaper, set it on every desktop, then delete the previous image. Offline or
# on any failure it leaves the current wallpaper untouched and exits quietly.
#
# The lock screen follows the desktop automatically once it is a normal photo.
# If it is an Aerial wallpaper, pick any photo once in System Settings > Wallpaper.
#
# No background process; launchd runs it on the interval you choose.

set -u

VERSION="1.1.0"
CREDIT="Made by Najam · https://najam.dev"

STORE_DIR="$HOME/Library/Application Support/BingWallpaper"
LOG_FILE="$HOME/Library/Logs/BingWallpaper.log"
CONFIG="$STORE_DIR/settings.conf"
HISTORY="$STORE_DIR/.history"
CURRENT="$STORE_DIR/.current"
FEED_DIR="$STORE_DIR/.feeds"
BING="https://www.bing.com"
MARKETS="en-US en-GB en-CA en-AU en-IN"

LABEL="dev.najam.bingwallpaper"
UID_NUM="$(id -u)"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
TARGET="$HOME/.local/bin/bingwall"

VALID_TYPES="landscapes cities beaches animals space everything"

usage() {
  cat <<EOF
bingwall $VERSION - a fresh Bing photo as your Mac wallpaper.

Usage:
  bingwall                     Fetch and set a new wallpaper now.
  bingwall --types LIST        Choose types (comma-separated) and remember them.
  bingwall --every INTERVAL    Set the schedule and remember it.
  bingwall --help              Show this help.
  bingwall --version           Show the version.

Types:      landscapes, cities, beaches, animals, space, everything
            (names may be shortened: landscapes,cities or landscapes,beaches)
Intervals:  1h, 3h, 6h, 12h (default), 24h, manual
Env vars:   BW_TYPES and BW_EVERY override the saved settings for one run.

Examples:
  bingwall --types landscapes,cities --every 6h
  BW_TYPES=space bingwall

Images: $STORE_DIR
Log:    $LOG_FILE

$CREDIT
EOF
}

# ---- settings -------------------------------------------------------------

# Capture environment overrides before the config file is sourced.
ENV_TYPES="${BW_TYPES:-}"
ENV_EVERY="${BW_EVERY:-}"
BW_TYPES="landscapes"
BW_EVERY="12h"
[ -f "$CONFIG" ] && . "$CONFIG"
[ -n "$ENV_TYPES" ] && BW_TYPES="$ENV_TYPES"
[ -n "$ENV_EVERY" ] && BW_EVERY="$ENV_EVERY"

normalize_types() {
  # Map friendly names to canonical ids; validate; ensure at least one.
  local raw="$1" out="" t canon
  IFS=',' read -ra parts <<< "$raw"
  for t in "${parts[@]}"; do
    t="$(printf '%s' "$t" | tr '[:upper:]' '[:lower:]' | xargs)"
    case "$t" in
      landscape|landscapes) canon="landscapes" ;;
      city|cities|architecture|"cities & architecture") canon="cities" ;;
      beach|beaches|island|islands|"beaches & islands") canon="beaches" ;;
      animal|animals|wildlife|"animals & wildlife") canon="animals" ;;
      space|night|"space & night sky") canon="space" ;;
      everything|all) canon="everything" ;;
      "") continue ;;
      *) printf 'Unknown type: %s\nValid: %s\n' "$t" "$VALID_TYPES" >&2; return 1 ;;
    esac
    case ",$out," in *",$canon,"*) ;; *) out="${out:+$out,}$canon" ;; esac
  done
  [ -n "$out" ] || out="landscapes"
  printf '%s' "$out"
}

normalize_every() {
  local v
  v="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  case "$v" in
    1h|3h|6h|12h|24h|manual) printf '%s' "$v" ;;
    *) printf 'Invalid interval: %s (use 1h, 3h, 6h, 12h, 24h, manual)\n' "$1" >&2; return 1 ;;
  esac
}

save_config() {
  mkdir -p "$STORE_DIR"
  printf 'BW_TYPES="%s"\nBW_EVERY="%s"\n' "$BW_TYPES" "$BW_EVERY" > "$CONFIG"
}

apply_schedule() {
  # Rewrite the LaunchAgent for the chosen interval, if it is installed.
  [ -f "$PLIST" ] || return 0
  local interval_xml runatload
  if [ "$BW_EVERY" = "manual" ]; then
    interval_xml=""
    runatload="<false/>"
  else
    local hours="${BW_EVERY%h}"
    interval_xml="    <key>StartInterval</key>
    <integer>$((hours * 3600))</integer>"
    runatload="<true/>"
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
$interval_xml
    <key>RunAtLoad</key>
    $runatload
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
  launchctl bootout "gui/$UID_NUM/$LABEL" 2>/dev/null || true
  launchctl bootstrap "gui/$UID_NUM" "$PLIST" 2>/dev/null || true
}

# ---- argument parsing -----------------------------------------------------

PERSIST_TYPES=""
PERSIST_EVERY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --version|-V) printf 'bingwall %s\n%s\n' "$VERSION" "$CREDIT"; exit 0 ;;
    --types)
      [ $# -ge 2 ] || { printf '--types needs a value\n' >&2; exit 2; }
      PERSIST_TYPES="$(normalize_types "$2")" || exit 2
      BW_TYPES="$PERSIST_TYPES"; shift 2 ;;
    --types=*)
      PERSIST_TYPES="$(normalize_types "${1#--types=}")" || exit 2
      BW_TYPES="$PERSIST_TYPES"; shift ;;
    --every)
      [ $# -ge 2 ] || { printf '--every needs a value\n' >&2; exit 2; }
      PERSIST_EVERY="$(normalize_every "$2")" || exit 2
      BW_EVERY="$PERSIST_EVERY"; shift 2 ;;
    --every=*)
      PERSIST_EVERY="$(normalize_every "${1#--every=}")" || exit 2
      BW_EVERY="$PERSIST_EVERY"; shift ;;
    *) printf 'Unknown option: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

# Env vars (BW_TYPES / BW_EVERY) were captured above as one-run overrides.
BW_TYPES="$(normalize_types "$BW_TYPES")" || exit 2
BW_EVERY="$(normalize_every "$BW_EVERY")" || exit 2

if [ -n "$PERSIST_TYPES" ] || [ -n "$PERSIST_EVERY" ]; then
  save_config
  [ -n "$PERSIST_EVERY" ] && apply_schedule
fi

mkdir -p "$STORE_DIR" "$(dirname "$LOG_FILE")"

log() {
  printf '%s | %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE"
  local lines
  lines="$(wc -l < "$LOG_FILE" 2>/dev/null | tr -d ' ')"
  if [ "${lines:-0}" -gt 200 ]; then
    tail -n 200 "$LOG_FILE" > "$LOG_FILE.tmp" && mv -f "$LOG_FILE.tmp" "$LOG_FILE"
  fi
}

# ---- single-instance lock -------------------------------------------------

LOCK="$STORE_DIR/.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
  now="$(date +%s)"
  mt="$(stat -f %m "$LOCK" 2>/dev/null || echo "$now")"
  if [ $((now - mt)) -gt 600 ]; then
    rmdir "$LOCK" 2>/dev/null
    mkdir "$LOCK" 2>/dev/null || exit 0
  else
    exit 0
  fi
fi
cleanup() {
  rm -rf "$FEED_DIR"
  rm -f "$STORE_DIR/.incoming.jpg"
  rmdir "$LOCK" 2>/dev/null
}
trap cleanup EXIT

current_id=""
[ -f "$CURRENT" ] && current_id="$(cat "$CURRENT" 2>/dev/null)"

# ---- fetch feeds ----------------------------------------------------------

mkdir -p "$FEED_DIR"
ok=0
for mkt in $MARKETS; do
  for idx in 0 8; do
    if curl -fsSL --connect-timeout 15 --max-time 60 \
      "$BING/HPImageArchive.aspx?format=js&idx=$idx&n=8&mkt=$mkt" \
      -o "$FEED_DIR/$mkt-$idx.json" 2>/dev/null; then
      ok=$((ok + 1))
    fi
  done
done
if [ "$ok" -eq 0 ]; then
  log "Network: could not fetch Bing feed. Keeping current wallpaper."
  exit 0
fi

# ---- filter and pick (Python) ---------------------------------------------

pick="$(BW_TYPES="$BW_TYPES" python3 - "$current_id" "$HISTORY" "$FEED_DIR" <<'PY'
import json, os, re, sys, glob

current, history_path, feed_dir = sys.argv[1], sys.argv[2], sys.argv[3]
types = [t for t in os.environ.get("BW_TYPES", "landscapes").split(",") if t]

# Keyword lists mirror app/Sources/Categories.swift. Edit to taste.
TYPES = {
    "landscapes": {
        "include": ["mountain","peak","summit","valley","lake","river","waterfall","falls","forest","woods","canyon","desert","dunes","coast","beach","cliff","island","bay","glacier","fjord","national park","meadow","hills","aurora","arch","trail","crag"],
        "exclude": ["flag","lantern","festival","diwali","city","district","street","church","cathedral","museum","bridge","building","tower","skyline","market","town","village","castle","palace","temple","monument","statue","boat","ship","car","train","people","crowd","bison","bear","bird","fox","whale","penguin","owl","deer","elephant","lion","tiger","wolf","eagle","horse","cow","sheep","goat","monkey","snake","lizard","turtle","frog","shark","dolphin","seal","otter","squirrel","rabbit","hare","butterfly","bee","camel","kangaroo","koala","panda","leopard","cheetah","zebra","giraffe","hippo","rhino","crocodile","alligator","flamingo","swan","duck","goose","parrot","peacock","insect","spider","fish"],
    },
    "cities": {"include": ["city","cityscape","skyline","downtown","architecture","building","skyscraper","tower","bridge","cathedral","church","castle","palace","museum","street","urban","town","village","temple","monument","plaza","market","harbor","district"], "exclude": []},
    "beaches": {"include": ["beach","island","bay","coast","coastline","shore","seaside","sand","tropical","reef","lagoon","atoll","ocean","sea","cove","archipelago","surf"], "exclude": []},
    "animals": {"include": ["animal","wildlife","bird","mammal","reptile","amphibian","insect","butterfly","bee","spider","fish","shark","whale","dolphin","seal","otter","penguin","owl","eagle","fox","bear","bison","deer","elk","moose","wolf","lion","tiger","leopard","cheetah","zebra","giraffe","elephant","rhino","hippo","crocodile","alligator","snake","lizard","turtle","frog","monkey","ape","kangaroo","koala","panda","camel","horse","cow","sheep","goat","swan","duck","goose","parrot","peacock","flamingo","squirrel","rabbit","hare","hedgehog","bat","crab","lobster","jellyfish","octopus","herd","flock","safari"], "exclude": []},
    "space": {"include": ["space","galaxy","nebula","star","night sky","starry","aurora","northern lights","moon","lunar","planet","mars","comet","meteor","milky way","eclipse","constellation","observatory","telescope","astronaut","cosmos","cosmic","night"], "exclude": []},
}

def build(words):
    stems = set()
    for w in words:
        w = w.lower()
        stems.add(w)
        if w.endswith("s") and len(w) > 3:
            stems.add(w[:-1])
    if not stems:
        return None
    return re.compile(r"\b(?:" + "|".join(re.escape(s) for s in sorted(stems)) + r")(?:s|es)?\b", re.I)

REGEX = {k: (build(v["include"]), build(v["exclude"])) for k, v in TYPES.items()}

def matches(title, copyright):
    if "everything" in types:
        return True
    text = title + " " + copyright
    for t in types:
        inc, exc = REGEX.get(t, (None, None))
        if inc and inc.search(text) and not (exc and exc.search(text)):
            return True
    return False

def scene(urlbase):
    ident = urlbase.split("id=")[-1]
    return ident.split("_")[0]

history = []
if os.path.exists(history_path):
    history = [l.strip() for l in open(history_path) if l.strip()]
hist_urls = set(history)
hist_scenes = {scene(u) for u in history}
cur_scene = scene(current) if current else ""

pool = {}
for path in glob.glob(os.path.join(feed_dir, "*.json")):
    mkt = os.path.basename(path).rsplit("-", 1)[0]
    try:
        data = json.load(open(path))
    except Exception:
        continue
    for img in data.get("images", []):
        ub = img.get("urlbase", "")
        if not ub:
            continue
        title = img.get("title", "")
        copyright = img.get("copyright", "")
        fsd = img.get("fullstartdate") or img.get("startdate") or ""
        # Prefer en-US and a real title over the generic "Info".
        rank = (0 if mkt == "en-US" else 1, 1 if title in ("", "Info") else 0)
        key = scene(ub)
        if key not in pool or rank < pool[key][0]:
            pool[key] = (rank, ub, title, copyright, fsd)

candidates = []
for key, (rank, ub, title, copyright, fsd) in pool.items():
    if ub in hist_urls or ub == current or key in hist_scenes or key == cur_scene:
        continue
    if matches(title, copyright):
        candidates.append((fsd, ub, title, copyright))

candidates.sort(reverse=True)
if candidates:
    _, ub, title, copyright = candidates[0]
    print(ub)
    print(title)
    print(copyright)
PY
)"

if [ -z "$pick" ]; then
  log "No new photo for types [$BW_TYPES]. Keeping current wallpaper."
  exit 0
fi

{ IFS= read -r urlbase; IFS= read -r title; IFS= read -r copyright; } <<< "$pick"
id="${urlbase##*id=}"
url="$BING${urlbase}_UHD.jpg"
tmp="$STORE_DIR/.incoming.jpg"
final="$STORE_DIR/$id.jpg"

rm -f "$tmp"
if ! curl -fsSL --connect-timeout 15 --max-time 180 "$url" -o "$tmp"; then
  log "Download failed for $url. Keeping current wallpaper."
  exit 0
fi

size="$(stat -f %z "$tmp" 2>/dev/null || echo 0)"
mime="$(file -b --mime-type "$tmp" 2>/dev/null)"
if [ "$size" -lt 100000 ] || [ "$mime" != "image/jpeg" ]; then
  log "Downloaded file is not a valid JPEG (size=$size, type=$mime). Keeping current wallpaper."
  exit 0
fi

mv -f "$tmp" "$final"
# Set the desktop from the fresh file. When the lock screen is a normal image,
# macOS moves its SystemDefault entry to this new file on its own.
if ! osascript -e 'tell application "System Events" to tell every desktop to set picture to POSIX file "'"$final"'"' >/dev/null 2>&1; then
  log "Could not set the wallpaper. Keeping the previous one."
  rm -f "$final"
  exit 0
fi

# Keep the current photo and whatever the lock screen still points at (read-only);
# the latter is deleted on a later run once the lock screen has moved on.
lock_file="$(python3 - <<'PY'
import plistlib, os, urllib.parse
p = os.path.expanduser("~/Library/Application Support/com.apple.wallpaper/Store/Index.plist")
try:
    r = plistlib.load(open(p, "rb"))
    c = r["SystemDefault"]["Desktop"]["Content"]["Choices"][0]
    u = plistlib.loads(c["Configuration"]).get("url", {}).get("relative", "")
    print(urllib.parse.unquote(urllib.parse.urlparse(u).path))
except Exception:
    print("")
PY
)"
for f in "$STORE_DIR"/*.jpg; do
  [ -e "$f" ] || continue
  [ "$f" = "$final" ] && continue
  if [ -n "$lock_file" ] && [ "$f" = "$lock_file" ]; then continue; fi
  rm -f "$f"
done

# ---- record state ---------------------------------------------------------

printf '%s\n' "$urlbase" > "$CURRENT"
printf '%s\n' "$urlbase" >> "$HISTORY"
tail -n 30 "$HISTORY" > "$HISTORY.tmp" && mv -f "$HISTORY.tmp" "$HISTORY"
log "Set wallpaper: $title | $copyright"
exit 0