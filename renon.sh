#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
#  RENON v4 — Termux Bulk Video Downloader
#  Facebook · YouTube · Instagram · TikTok · Pinterest
#  Twitter/X · Reddit · Vimeo · Dailymotion · LinkedIn · more
#  FULLY AUTOMATIC — no menus, no questions, just paste & go
# ============================================================

RED='\033[0;31m';    GREEN='\033[0;32m'
YELLOW='\033[1;33m'; CYAN='\033[0;36m'
WHITE='\033[1;37m';  DIM='\033[2m'; BOLD='\033[1m'; NC='\033[0m'

SAVE_DIR="$HOME/storage/downloads/RENON"
CONFIG_DIR="$HOME/.config/renon"
COOKIES_FILE="$CONFIG_DIR/cookies.txt"
LOG_FILE="$CONFIG_DIR/renon.log"
FAILED_FILE="$CONFIG_DIR/failed_urls.txt"
PREFS_FILE="$CONFIG_DIR/prefs.conf"
SHORTCUT_FILE="$HOME/.shortcuts/RENON"
MAX_RETRIES=5
FORMAT_MERGE="mp4"
AUDIO_ONLY=0

mkdir -p "$CONFIG_DIR" "$SAVE_DIR"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

# ── Banner ───────────────────────────────────────────────────
clear
echo -e "${CYAN}"
echo "  ██████╗ ███████╗███╗   ██╗ ██████╗ ███╗   ██╗"
echo "  ██╔══██╗██╔════╝████╗  ██║██╔═══██╗████╗  ██║"
echo "  ██████╔╝█████╗  ██╔██╗ ██║██║   ██║██╔██╗ ██║"
echo "  ██╔══██╗██╔══╝  ██║╚██╗██║██║   ██║██║╚██╗██║"
echo "  ██║  ██║███████╗██║ ╚████║╚██████╔╝██║ ╚████║"
echo "  ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═══╝"
echo -e "${NC}${DIM}  v4 · Auto-everything · Paste & Go · No menus${NC}"
echo ""
echo -e "${DIM}  ─────────────────────────────────────────────────────${NC}"
echo ""

# ════════════════════════════════════════════════════════════
# STEP 1 — DEPENDENCIES (silent after first run)
# ════════════════════════════════════════════════════════════
echo -e "${CYAN}[1/4] SETUP${NC}"
echo ""

pkg_install() {
    local pkg="$1" cmd="${2:-$1}"
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "  ${YELLOW}⬇ Installing $pkg...${NC}"
        pkg install -y "$pkg" > /dev/null 2>&1
        command -v "$cmd" &>/dev/null \
            && echo -e "  ${GREEN}✔ $pkg installed${NC}" \
            || echo -e "  ${RED}✘ $pkg failed — some features may not work${NC}"
    else
        echo -e "  ${GREEN}✔ $pkg${NC}${DIM} ready${NC}"
    fi
}

pkg_install python python3
pkg_install ffmpeg ffmpeg
pkg_install curl curl
pkg_install wget wget
pkg_install jq jq
pkg_install openssl-tool openssl

if ! command -v yt-dlp &>/dev/null; then
    echo -e "  ${YELLOW}⬇ Installing yt-dlp...${NC}"
    pip install -q yt-dlp && echo -e "  ${GREEN}✔ yt-dlp installed${NC}"
else
    echo -e "  ${YELLOW}↑ Upgrading yt-dlp...${NC}"
    pip install -q --upgrade yt-dlp 2>/dev/null \
        && echo -e "  ${GREEN}✔ yt-dlp up to date${NC}" \
        || echo -e "  ${DIM}  yt-dlp upgrade skipped${NC}"
fi

# Storage
if [ ! -d "$HOME/storage" ]; then
    echo -e "  ${YELLOW}Requesting storage access...${NC}"
    termux-setup-storage; sleep 3
fi
mkdir -p "$SAVE_DIR"

# Home screen shortcut — one time only
if [ ! -f "$SHORTCUT_FILE" ]; then
    mkdir -p "$HOME/.shortcuts"
    SCRIPT_PATH="$(realpath "$0")"
    printf '#!/data/data/com.termux/files/usr/bin/bash\nbash "%s"\n' \
        "$SCRIPT_PATH" > "$SHORTCUT_FILE"
    chmod +x "$SHORTCUT_FILE"
    echo -e "  ${GREEN}✔ Widget shortcut created — add via Termux:Widget${NC}"
fi

echo ""
echo -e "  ${DIM}📁 $SAVE_DIR${NC}"
echo -e "  ${DIM}📋 $LOG_FILE${NC}"
echo ""
echo -e "${DIM}  ─────────────────────────────────────────────────────${NC}"
echo ""

# ════════════════════════════════════════════════════════════
# STEP 2 — NETWORK
# ════════════════════════════════════════════════════════════
echo -e "${CYAN}[2/4] NETWORK${NC}"
echo ""

NET_OK=0
for h in "google.com" "cloudflare.com" "1.1.1.1"; do
    curl -s --max-time 4 --head "https://$h" &>/dev/null && NET_OK=1 && break
done

if [ $NET_OK -eq 1 ]; then
    LATENCY=$(curl -s -o /dev/null -w "%{time_total}" --max-time 5 \
        https://google.com 2>/dev/null)
    echo -e "  ${GREEN}✔ Connected${NC}${DIM} · latency ${LATENCY}s${NC}"
else
    echo -e "  ${RED}✘ No internet. Connect and retry.${NC}"
    log "ABORT: no internet"; exit 1
fi

echo ""
echo -e "${DIM}  ─────────────────────────────────────────────────────${NC}"
echo ""

# ════════════════════════════════════════════════════════════
# AUTO-DETECT COOKIES — no menu, fully automatic
# Tries every available method in order of reliability:
#   1. Saved cookies.txt from a previous session
#   2. Firefox browser (if installed)
#   3. Chrome browser (if installed)
#   4. No cookies (public videos still work fine)
# ════════════════════════════════════════════════════════════
echo -e "${CYAN}[3/4] AUTO-SETUP${NC}"
echo ""

COOKIE_ARGS=()
COOKIE_SOURCE="none"

# — Method 1: saved cookies.txt from last run ────────────────
if [ -f "$COOKIES_FILE" ] && [ -s "$COOKIES_FILE" ]; then
    COOKIE_ARGS=("--cookies" "$COOKIES_FILE")
    COOKIE_SOURCE="saved file"
    echo -e "  ${GREEN}✔ Cookies: saved file${NC}${DIM} ($COOKIES_FILE)${NC}"
fi

# — Method 2: Firefox (if cookies.txt not found) ─────────────
if [ "$COOKIE_SOURCE" = "none" ]; then
    FF_DIRS=(
        "$HOME/.mozilla/firefox"
        "/data/data/org.mozilla.firefox/files/mozilla"
        "/sdcard/Android/data/org.mozilla.firefox/files/mozilla"
    )
    for d in "${FF_DIRS[@]}"; do
        if [ -d "$d" ]; then
            # Export once and save so future runs use Method 1
            yt-dlp --cookies-from-browser firefox \
                --skip-download \
                "https://www.facebook.com" \
                -o /dev/null 2>/dev/null
            if [ $? -eq 0 ]; then
                COOKIE_ARGS=("--cookies-from-browser" "firefox")
                COOKIE_SOURCE="firefox"
                echo -e "  ${GREEN}✔ Cookies: Firefox${NC}"
            fi
            break
        fi
    done
fi

# — Method 3: Chrome ─────────────────────────────────────────
if [ "$COOKIE_SOURCE" = "none" ]; then
    CHROME_DIRS=(
        "/data/data/com.android.chrome/app_chrome/Default"
        "/data/data/com.chrome.beta/app_chrome/Default"
    )
    for d in "${CHROME_DIRS[@]}"; do
        if [ -d "$d" ]; then
            yt-dlp --cookies-from-browser chrome \
                --skip-download \
                "https://www.youtube.com" \
                -o /dev/null 2>/dev/null
            if [ $? -eq 0 ]; then
                COOKIE_ARGS=("--cookies-from-browser" "chrome")
                COOKIE_SOURCE="chrome"
                echo -e "  ${GREEN}✔ Cookies: Chrome${NC}"
            fi
            break
        fi
    done
fi

# — No cookies found ─────────────────────────────────────────
if [ "$COOKIE_SOURCE" = "none" ]; then
    echo -e "  ${DIM}ℹ No browser cookies found — public videos only${NC}"
    echo -e "  ${DIM}  To unlock Facebook/private: export cookies.txt from"
    echo -e "  Firefox using the 'cookies.txt' add-on, save it to"
    echo -e "  Downloads, then run:${NC}"
    echo -e "  ${YELLOW}  cp /sdcard/Download/cookies.txt $COOKIES_FILE${NC}"
fi

# — Auto quality: always best MP4 1080p ──────────────────────
FORMAT_ARGS=(
    "-f"
    "bestvideo[height<=1080][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=1080]+bestaudio/best[height<=1080]/best"
)
echo -e "  ${GREEN}✔ Quality: best MP4 up to 1080p${NC}"

echo ""
echo -e "${DIM}  ─────────────────────────────────────────────────────${NC}"
echo ""

# ════════════════════════════════════════════════════════════
# STEP 3 — COLLECT, HEAL & NORMALISE URLs
# ════════════════════════════════════════════════════════════
echo -e "${CYAN}[4/4] PASTE YOUR LINKS${NC}"
echo ""
echo -e "  ${DIM}Paste everything at once — press ENTER on a blank line when done${NC}"
echo ""

# Offer retry of previous failures
PREFILL=""
if [ -f "$FAILED_FILE" ] && [ -s "$FAILED_FILE" ]; then
    FAIL_COUNT=$(wc -l < "$FAILED_FILE")
    echo -e "  ${YELLOW}⚠  $FAIL_COUNT failed URL(s) from last run — retry them? [Y/n]:${NC} \c"
    read -r RETRY_ANS
    RETRY_ANS="${RETRY_ANS:-y}"
    [[ "$RETRY_ANS" =~ ^[Yy]$ ]] && PREFILL=$(cat "$FAILED_FILE") \
        && echo -e "  ${GREEN}✔ Added to queue${NC}"
    echo ""
fi

RAW_INPUT=()
if [ -n "$PREFILL" ]; then
    while IFS= read -r line; do
        [[ -n "$line" ]] && RAW_INPUT+=("$line")
    done <<< "$PREFILL"
fi
while IFS= read -r line; do
    [[ -z "$line" ]] && break
    RAW_INPUT+=("$line")
done

# ── Heal split URLs ──────────────────────────────────────────
# Fixes lines broken mid-URL by copy-paste on Android
# e.g.  "https://www.facebook.com/share/r"
#       "/1bfZJsxqtv/"
# Also fixes "https:/" split scheme lines
heal_urls() {
    local joined=""
    for raw in "${RAW_INPUT[@]}"; do
        raw="$(echo "$raw" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [[ -z "$raw" ]] && continue

        if [[ -n "$joined" ]]; then
            if [[ "$raw" == /* ]]; then
                joined="${joined}${raw}"
                if [[ "$joined" =~ ^https?://[^[:space:]]+\.[^[:space:]]+ ]]; then
                    echo "$joined"; joined=""
                fi
                continue
            else
                # continuation doesn't start with / — flush fragment as-is
                echo "$joined"; joined=""
            fi
        fi

        # Detect broken scheme
        if [[ "$raw" == "https:/" || "$raw" == "http:/" || \
              "$raw" == "https:"  || "$raw" == "http:"  ]]; then
            joined="$raw"; continue
        fi

        echo "$raw"
    done
    [[ -n "$joined" ]] && echo "$joined"
}

normalize_url() {
    local url="$1"
    url="$(echo "$url" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -z "$url" ]] && return
    url="$(echo "$url" | sed \
        's|https:/[[:space:]]*/|https://|g;s|http:/[[:space:]]*/|http://|g')"
    [[ "$url" != http://* && "$url" != https://* ]] && url="https://$url"
    url="${url/http:\/\//https://}"
    echo "$url"
}

detect_platform() {
    case "$1" in
        *facebook.com*|*fb.watch*)   echo "Facebook" ;;
        *youtube.com*|*youtu.be*)    echo "YouTube" ;;
        *instagram.com*)             echo "Instagram" ;;
        *tiktok.com*)                echo "TikTok" ;;
        *twitter.com*|*x.com*)       echo "Twitter/X" ;;
        *reddit.com*|*redd.it*)      echo "Reddit" ;;
        *pinterest.com*|*pin.it*)    echo "Pinterest" ;;
        *vimeo.com*)                 echo "Vimeo" ;;
        *dailymotion.com*)           echo "Dailymotion" ;;
        *linkedin.com*)              echo "LinkedIn" ;;
        *twitch.tv*)                 echo "Twitch" ;;
        *streamable.com*)            echo "Streamable" ;;
        *rumble.com*)                echo "Rumble" ;;
        *)                           echo "Web" ;;
    esac
}

# Rebuild with healed URLs
HEALED=()
while IFS= read -r line; do HEALED+=("$line"); done < <(heal_urls)
RAW_INPUT=("${HEALED[@]}")

echo ""
echo -e "  ${WHITE}Checking URLs...${NC}"
echo ""

CLEAN_URLS=()
SEEN_URLS=()
DUPES=0; INVALID=0

for raw in "${RAW_INPUT[@]}"; do
    [[ -z "$raw" || "$raw" == \#* ]] && continue
    norm="$(normalize_url "$raw")"
    [[ -z "$norm" ]] && continue

    if ! [[ "$norm" =~ ^https://[^[:space:]]+\.[^[:space:]]+ ]]; then
        echo -e "  ${RED}✘ Invalid:${NC} ${DIM}$raw${NC}"
        ((INVALID++)); continue
    fi

    if [[ " ${SEEN_URLS[*]} " == *" $norm "* ]]; then
        ((DUPES++)); continue
    fi

    SEEN_URLS+=("$norm")
    CLEAN_URLS+=("$norm")
    PLATFORM="$(detect_platform "$norm")"
    echo -e "  ${GREEN}✔${NC} ${CYAN}[$PLATFORM]${NC} ${DIM}$norm${NC}"
done

echo ""
echo -e "  ${BOLD}${#CLEAN_URLS[@]} URL(s) ready${NC}${DIM} · $DUPES dupes removed · $INVALID invalid${NC}"

[ ${#CLEAN_URLS[@]} -eq 0 ] && echo -e "  ${RED}✘ Nothing to download.${NC}" && exit 1

echo ""
echo -e "${DIM}  ─────────────────────────────────────────────────────${NC}"
echo ""
echo -e "${CYAN}[DOWNLOADING]${NC} ${DIM}→ $SAVE_DIR${NC}"
echo ""

> "$FAILED_FILE"
SUCCESS=0; FAILED=0; FAILED_URLS=()
TOTAL=${#CLEAN_URLS[@]}; INDEX=0
OUT_TMPL="$SAVE_DIR/%(upload_date>%Y-%m-%d)s_%(uploader).30s_%(title).50s.%(ext)s"

# ════════════════════════════════════════════════════════════
# DOWNLOAD FUNCTION
# ════════════════════════════════════════════════════════════
download_url() {
    local url="$1" index="$2"
    local platform; platform="$(detect_platform "$url")"

    echo -e "  ${CYAN}[$index/$TOTAL]${NC} ${BOLD}$platform${NC}"
    echo -e "  ${DIM}$url${NC}"

    local BASE_ARGS=(
        "${FORMAT_ARGS[@]}"
        "--merge-output-format" "$FORMAT_MERGE"
        "--no-playlist"
        "--retries"             "$MAX_RETRIES"
        "--fragment-retries"    "$MAX_RETRIES"
        "--retry-sleep"         "3"
        "--file-access-retries" "3"
        "--extractor-retries"   "3"
        "--socket-timeout"      "30"
        "--output"              "$OUT_TMPL"
        "--add-metadata"
        "--embed-thumbnail"
        "--no-overwrites"
        "--windows-filenames"
        "--no-warnings"
        "--newline"
    )
    [ ${#COOKIE_ARGS[@]} -gt 0 ] && BASE_ARGS+=("${COOKIE_ARGS[@]}")

    # Platform tweaks
    case "$platform" in
        Facebook)
            BASE_ARGS+=(
                "--add-header" "Accept-Language:en-US,en;q=0.9"
                "--add-header" "Accept:text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
            ) ;;
        YouTube)   BASE_ARGS+=("--prefer-free-formats") ;;
        Instagram) BASE_ARGS+=("--add-header" "Accept-Language:en-US,en;q=0.9") ;;
        TikTok)    BASE_ARGS+=("--extractor-args" \
                       "tiktok:api_hostname=api22-normal-c-useast2a.tiktokv.com") ;;
        Pinterest) BASE_ARGS+=(
                       "--add-header" "Accept-Language:en-US,en;q=0.9"
                       "--add-header" "Referer:https://www.pinterest.com/") ;;
        Twitter/X) BASE_ARGS+=("--add-header" "Accept-Language:en-US,en;q=0.9") ;;
        Reddit)    BASE_ARGS+=("--add-header" "Accept-Language:en-US,en;q=0.9") ;;
    esac

    local FALLBACK_ARGS=(
        "-f" "best/bestvideo+bestaudio"
        "--merge-output-format" "$FORMAT_MERGE"
        "--no-playlist" "--retries" "$MAX_RETRIES"
        "--socket-timeout" "30"
        "--output" "$OUT_TMPL"
        "--no-overwrites" "--windows-filenames"
        "--no-warnings" "--quiet"
    )
    [ ${#COOKIE_ARGS[@]} -gt 0 ] && FALLBACK_ARGS+=("${COOKIE_ARGS[@]}")

    # ── Attempt 1: full quality ──────────────────────────────
    echo -e "  ${DIM}  ▶ 1/4 direct...${NC}"
    yt-dlp "${BASE_ARGS[@]}" --quiet "$url" 2>/dev/null
    [ $? -eq 0 ] && echo -e "  ${GREEN}✔ Done${NC}" \
        && log "OK[1]: $url" && return 0

    # ── Attempt 2: simple format fallback ───────────────────
    echo -e "  ${YELLOW}  ▶ 2/4 fallback format...${NC}"
    yt-dlp "${FALLBACK_ARGS[@]}" "$url" 2>/dev/null
    [ $? -eq 0 ] && echo -e "  ${GREEN}✔ Done (fallback)${NC}" \
        && log "OK[2]: $url" && return 0

    # ── Attempt 3: saved cookies.txt ────────────────────────
    if [ -f "$COOKIES_FILE" ] && [ "$COOKIE_SOURCE" != "saved file" ]; then
        echo -e "  ${YELLOW}  ▶ 3/4 saved cookies...${NC}"
        yt-dlp "${FALLBACK_ARGS[@]}" --cookies "$COOKIES_FILE" \
            --quiet "$url" 2>/dev/null
        [ $? -eq 0 ] && echo -e "  ${GREEN}✔ Done (cookies)${NC}" \
            && log "OK[3]: $url" && return 0
    fi

    # ── Attempt 4: Firefox direct ────────────────────────────
    if [ "$COOKIE_SOURCE" != "firefox" ]; then
        echo -e "  ${YELLOW}  ▶ 4/4 Firefox cookies...${NC}"
        yt-dlp "${FALLBACK_ARGS[@]}" --cookies-from-browser firefox \
            --quiet "$url" 2>/dev/null
        [ $? -eq 0 ] && echo -e "  ${GREEN}✔ Done (Firefox)${NC}" \
            && log "OK[4]: $url" && return 0
    fi

    echo -e "  ${RED}✘ Failed${NC}"
    log "FAIL: $url"
    echo "$url" >> "$FAILED_FILE"
    return 1
}

# ── Run queue ────────────────────────────────────────────────
for url in "${CLEAN_URLS[@]}"; do
    ((INDEX++))
    echo -e "${DIM}  ·····················································${NC}"
    download_url "$url" "$INDEX"
    [ $? -eq 0 ] && ((SUCCESS++)) || { ((FAILED++)); FAILED_URLS+=("$url"); }
    echo ""
done

# ════════════════════════════════════════════════════════════
# SUMMARY
# ════════════════════════════════════════════════════════════
echo -e "${DIM}  ═════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${BOLD}${WHITE}RENON — DONE${NC}"
echo ""
echo -e "  ${GREEN}✔ Done    : $SUCCESS / $TOTAL${NC}"
[ $FAILED -gt 0 ] && echo -e "  ${RED}✘ Failed  : $FAILED / $TOTAL${NC}"
echo -e "  ${CYAN}📁 Folder : $SAVE_DIR${NC}"
echo ""

if [ ${#FAILED_URLS[@]} -gt 0 ]; then
    echo -e "${YELLOW}  Failed — will retry next run:${NC}"
    for u in "${FAILED_URLS[@]}"; do
        echo -e "  ${DIM}  → $u${NC}"
    done
    echo ""
    echo -e "${DIM}  To unlock Facebook/private videos, run this once:${NC}"
    echo -e "${YELLOW}  cp /sdcard/Download/cookies.txt $COOKIES_FILE${NC}"
    echo -e "${DIM}  (export cookies.txt from Firefox using the 'cookies.txt' add-on)${NC}"
fi

echo ""
echo -e "${DIM}  ═════════════════════════════════════════════════════${NC}"
echo ""
log "DONE — ok=$SUCCESS fail=$FAILED total=$TOTAL"
