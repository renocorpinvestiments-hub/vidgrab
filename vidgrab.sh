#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
#  RENON v3 — Termux Bulk Video Downloader
#  Facebook · YouTube · Instagram · TikTok · Pinterest
#  Twitter/X · Reddit · Vimeo · Dailymotion · LinkedIn · more
# ============================================================

# ── Colours ─────────────────────────────────────────────────
RED='\033[0;31m';    GREEN='\033[0;32m'
YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BLUE='\033[0;34m';   MAGENTA='\033[0;35m'
WHITE='\033[1;37m';  DIM='\033[2m';  BOLD='\033[1m'; NC='\033[0m'

# ── Config ───────────────────────────────────────────────────
SAVE_DIR="$HOME/storage/downloads/RENON"
CONFIG_DIR="$HOME/.config/renon"
COOKIES_FILE="$CONFIG_DIR/cookies.txt"
LOG_FILE="$CONFIG_DIR/renon.log"
FAILED_FILE="$CONFIG_DIR/failed_urls.txt"
SHORTCUT_FILE="$HOME/.shortcuts/RENON"
MAX_RETRIES=5

mkdir -p "$CONFIG_DIR"

# ── Logging ──────────────────────────────────────────────────
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
echo -e "${NC}${DIM}  v3 · Bulk · Cookie auth · Auto-retry · Pinterest & more${NC}"
echo ""
echo -e "${DIM}  ─────────────────────────────────────────────────────${NC}"
echo ""

# ════════════════════════════════════════════════════════════
# STEP 1 — DEPENDENCIES
# ════════════════════════════════════════════════════════════
echo -e "${CYAN}[1/6] SETUP${NC} — Checking & installing tools..."
echo ""

pkg_install() {
    local pkg="$1" cmd="${2:-$1}"
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "  ${YELLOW}⬇ Installing $pkg...${NC}"
        pkg install -y "$pkg" > /dev/null 2>&1
        command -v "$cmd" &>/dev/null \
            && echo -e "  ${GREEN}✔ $pkg installed${NC}" \
            || echo -e "  ${RED}✘ Could not install $pkg — some features may fail${NC}"
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

# yt-dlp — install or upgrade
if ! command -v yt-dlp &>/dev/null; then
    echo -e "  ${YELLOW}⬇ Installing yt-dlp...${NC}"
    pip install -q yt-dlp && echo -e "  ${GREEN}✔ yt-dlp installed${NC}"
else
    echo -e "  ${YELLOW}↑ Upgrading yt-dlp...${NC}"
    pip install -q --upgrade yt-dlp 2>/dev/null \
        && echo -e "  ${GREEN}✔ yt-dlp up to date${NC}" \
        || echo -e "  ${DIM}  yt-dlp upgrade skipped${NC}"
fi

# Storage permission
if [ ! -d "$HOME/storage" ]; then
    echo ""
    echo -e "  ${YELLOW}Requesting storage access...${NC}"
    termux-setup-storage
    sleep 3
fi

mkdir -p "$SAVE_DIR"
echo ""
echo -e "  ${DIM}📁 Save folder : $SAVE_DIR${NC}"
echo -e "  ${DIM}📋 Log file    : $LOG_FILE${NC}"

# ── Home screen shortcut (one-time) ──────────────────────────
if [ ! -f "$SHORTCUT_FILE" ]; then
    mkdir -p "$HOME/.shortcuts"
    SCRIPT_PATH="$(realpath "$0")"
    cat > "$SHORTCUT_FILE" << SHORTCUT
#!/data/data/com.termux/files/usr/bin/bash
bash "$SCRIPT_PATH"
SHORTCUT
    chmod +x "$SHORTCUT_FILE"
    echo ""
    echo -e "  ${GREEN}✔ Home screen shortcut created!${NC}"
    echo -e "  ${DIM}  Long-press your home screen → Widgets → Termux"
    echo -e "  → Termux:Widget → select RENON${NC}"
fi

echo ""
echo -e "${DIM}  ─────────────────────────────────────────────────────${NC}"
echo ""

# ════════════════════════════════════════════════════════════
# STEP 2 — INTERNET CHECK
# ════════════════════════════════════════════════════════════
echo -e "${CYAN}[2/6] NETWORK${NC} — Checking connection..."
echo ""

check_internet() {
    local hosts=("google.com" "cloudflare.com" "1.1.1.1")
    for h in "${hosts[@]}"; do
        curl -s --max-time 4 --head "https://$h" &>/dev/null && return 0
    done
    return 1
}

if check_internet; then
    echo -e "  ${GREEN}✔ Internet connected${NC}"
    LATENCY=$(curl -s -o /dev/null -w "%{time_total}" --max-time 5 https://google.com 2>/dev/null)
    echo -e "  ${DIM}  Latency: ${LATENCY}s${NC}"
else
    echo -e "  ${RED}✘ No internet. Connect to WiFi or mobile data and retry.${NC}"
    log "ABORT: no internet"
    exit 1
fi

echo ""
echo -e "${DIM}  ─────────────────────────────────────────────────────${NC}"
echo ""

# ════════════════════════════════════════════════════════════
# STEP 3 — COOKIE SETUP
# ════════════════════════════════════════════════════════════
echo -e "${CYAN}[3/6] COOKIES${NC} — Login auth for private/restricted videos"
echo ""
echo -e "  ${DIM}Cookies unlock: Facebook reels, private posts,"
echo -e "  age-restricted YouTube, Pinterest saves, and more.${NC}"
echo ""
echo -e "  ${WHITE}Choose cookie method:${NC}"
echo ""
echo -e "  ${GREEN}[1]${NC} Use saved cookies file  ${DIM}(from a previous run)${NC}"
echo -e "  ${GREEN}[2]${NC} Export from Firefox     ${DIM}(recommended for Android)${NC}"
echo -e "  ${GREEN}[3]${NC} Export from Chrome"
echo -e "  ${GREEN}[4]${NC} Load cookies.txt manually  ${DIM}(paste file path)${NC}"
echo -e "  ${GREEN}[5]${NC} Skip  ${DIM}(public videos only — no login needed)${NC}"
echo ""
read -r -p "  Choice [1-5] (default=5): " COOKIE_CHOICE
COOKIE_CHOICE="${COOKIE_CHOICE:-5}"
echo ""

COOKIE_ARGS=()

case "$COOKIE_CHOICE" in
    1)
        if [ -f "$COOKIES_FILE" ]; then
            COOKIE_ARGS=("--cookies" "$COOKIES_FILE")
            echo -e "  ${GREEN}✔ Using saved cookies: $COOKIES_FILE${NC}"
        else
            echo -e "  ${YELLOW}⚠ No saved cookies file found.${NC}"
            echo -e "  ${DIM}  Run RENON once with option [4] to load one first.${NC}"
        fi
        ;;
    2)
        echo -e "  ${YELLOW}Attempting Firefox cookie export...${NC}"
        echo ""
        echo -e "  ${DIM}On Android, Firefox protects its cookies folder."
        echo -e "  If auto-export fails, do this instead:"
        echo -e ""
        echo -e "  1. Open Firefox → go to addons.mozilla.org"
        echo -e "  2. Search: cookies.txt  (by Lennon Hill) → Install"
        echo -e "  3. Log into Facebook + YouTube in Firefox"
        echo -e "  4. Tap the extension → Export → save as cookies.txt"
        echo -e "     to your Downloads folder"
        echo -e "  5. Re-run RENON and use option [4] to load that file${NC}"
        echo ""
        # Try known Android Firefox profile paths
        FF_DIRS=(
            "$HOME/.mozilla/firefox"
            "/data/data/org.mozilla.firefox/files/mozilla"
            "/sdcard/Android/data/org.mozilla.firefox/files/mozilla"
        )
        FF_OK=0
        for d in "${FF_DIRS[@]}"; do
            [ -d "$d" ] && FF_OK=1 && break
        done
        if [ $FF_OK -eq 1 ]; then
            yt-dlp --cookies-from-browser firefox --skip-download \
                "https://www.facebook.com" -o /dev/null 2>/dev/null \
                && COOKIE_ARGS=("--cookies-from-browser" "firefox") \
                && echo -e "  ${GREEN}✔ Firefox cookies ready${NC}" \
                || echo -e "  ${YELLOW}⚠ Auto-export failed — use option [4] with manual cookies.txt${NC}"
        else
            echo -e "  ${YELLOW}⚠ Firefox profile not found — use option [4] with manual export${NC}"
        fi
        ;;
    3)
        echo -e "  ${YELLOW}Exporting Chrome cookies...${NC}"
        echo -e "  ${DIM}  Close Chrome first.${NC}"
        sleep 1
        yt-dlp --cookies-from-browser chrome --skip-download \
            "https://www.youtube.com" -o /dev/null 2>/dev/null \
            && COOKIE_ARGS=("--cookies-from-browser" "chrome") \
            && echo -e "  ${GREEN}✔ Chrome cookies ready${NC}" \
            || echo -e "  ${RED}✘ Chrome cookies failed — is Chrome installed?${NC}"
        ;;
    4)
        echo -e "  ${DIM}Common path: /sdcard/Download/cookies.txt${NC}"
        read -r -p "  Paste full path to cookies.txt: " CUSTOM_COOKIES
        CUSTOM_COOKIES="$(echo "$CUSTOM_COOKIES" | tr -d "'\"")"
        if [ -f "$CUSTOM_COOKIES" ]; then
            cp "$CUSTOM_COOKIES" "$COOKIES_FILE"
            COOKIE_ARGS=("--cookies" "$COOKIES_FILE")
            echo -e "  ${GREEN}✔ Cookies saved and ready: $COOKIES_FILE${NC}"
        else
            echo -e "  ${RED}✘ File not found: $CUSTOM_COOKIES${NC}"
            echo -e "  ${DIM}  Continuing without cookies.${NC}"
        fi
        ;;
    5|*)
        echo -e "  ${DIM}Skipping — public videos only.${NC}"
        ;;
esac

echo ""
echo -e "${DIM}  ─────────────────────────────────────────────────────${NC}"
echo ""

# ════════════════════════════════════════════════════════════
# STEP 4 — QUALITY / FORMAT
# ════════════════════════════════════════════════════════════
echo -e "${CYAN}[4/6] FORMAT${NC} — Choose download quality"
echo ""
echo -e "  ${GREEN}[1]${NC} Best MP4 up to 1080p   ${DIM}(recommended)${NC}"
echo -e "  ${GREEN}[2]${NC} Best MP4 up to 720p    ${DIM}(saves storage)${NC}"
echo -e "  ${GREEN}[3]${NC} Best MP4 up to 480p    ${DIM}(slow data / small files)${NC}"
echo -e "  ${GREEN}[4]${NC} Audio only — MP3       ${DIM}(music / podcasts)${NC}"
echo -e "  ${GREEN}[5]${NC} Best possible — no cap ${DIM}(4K if available)${NC}"
echo ""
read -r -p "  Choice [1-5] (default=1): " QUALITY_CHOICE
QUALITY_CHOICE="${QUALITY_CHOICE:-1}"
echo ""

case "$QUALITY_CHOICE" in
    1)  FORMAT_ARGS=("-f" "bestvideo[height<=1080][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=1080]+bestaudio/best[height<=1080]/best")
        FORMAT_MERGE="mp4"; AUDIO_ONLY=0 ;;
    2)  FORMAT_ARGS=("-f" "bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=720]+bestaudio/best[height<=720]/best")
        FORMAT_MERGE="mp4"; AUDIO_ONLY=0 ;;
    3)  FORMAT_ARGS=("-f" "bestvideo[height<=480][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=480]+bestaudio/best[height<=480]/best")
        FORMAT_MERGE="mp4"; AUDIO_ONLY=0 ;;
    4)  FORMAT_ARGS=("-f" "bestaudio/best" "-x" "--audio-format" "mp3" "--audio-quality" "0")
        FORMAT_MERGE="mp3"; AUDIO_ONLY=1 ;;
    5)  FORMAT_ARGS=("-f" "bestvideo+bestaudio/best")
        FORMAT_MERGE="mp4"; AUDIO_ONLY=0 ;;
    *)  FORMAT_ARGS=("-f" "bestvideo[height<=1080]+bestaudio/best")
        FORMAT_MERGE="mp4"; AUDIO_ONLY=0 ;;
esac

echo -e "  ${GREEN}✔ Format selected${NC}"
echo ""
echo -e "${DIM}  ─────────────────────────────────────────────────────${NC}"
echo ""

# ════════════════════════════════════════════════════════════
# STEP 5 — COLLECT, HEAL & NORMALISE URLs
# ════════════════════════════════════════════════════════════
echo -e "${CYAN}[5/6] URLs${NC} — Paste your links"
echo ""
echo -e "  ${DIM}• Paste your whole chunk at once — blank lines ignored"
echo -e "  • Mix any platforms freely (Facebook, YouTube, Pinterest...)"
echo -e "  • Broken/split URLs are auto-repaired"
echo -e "  • Duplicates are removed automatically"
echo -e "  • Press ENTER on an empty line when done${NC}"
echo ""

# Offer to retry previously failed URLs
PREFILL=""
if [ -f "$FAILED_FILE" ] && [ -s "$FAILED_FILE" ]; then
    FAIL_COUNT=$(wc -l < "$FAILED_FILE")
    echo -e "  ${YELLOW}⚠ $FAIL_COUNT previously failed URL(s) found${NC}"
    read -r -p "  Add them to this batch? [y/N]: " ADD_FAILED
    [[ "$ADD_FAILED" =~ ^[Yy]$ ]] && PREFILL=$(cat "$FAILED_FILE") \
        && echo -e "  ${GREEN}✔ Previous failures added to queue${NC}"
    echo ""
fi

# Collect raw input
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

# ── Auto-heal split/broken URLs ──────────────────────────────
# Handles cases like:
#   "https://www.facebook.com/share/r"   ← line break mid-URL
#   "/1bfZJsxqtv/"                       ← continuation on next line
#   "https:/"                            ← scheme split by newline
#   "/www.site.com/path"
heal_and_split_urls() {
    local joined=""
    for raw in "${RAW_INPUT[@]}"; do
        raw="$(echo "$raw" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [[ -z "$raw" ]] && continue

        if [[ -n "$joined" ]]; then
            # Try to attach continuation to previous fragment
            if [[ "$raw" == /* || "$raw" =~ ^[a-zA-Z0-9._~:@!$&()*+,;=%-] ]]; then
                joined="${joined}${raw}"
                # Looks like a complete URL now — emit it
                if [[ "$joined" =~ ^https?://[^[:space:]]+\.[^[:space:]]+ ]]; then
                    echo "$joined"
                    joined=""
                fi
                continue
            else
                # Can't complete the fragment — discard
                joined=""
            fi
        fi

        # Broken scheme fragments
        if [[ "$raw" == "https:/" || "$raw" == "http:/" || \
              "$raw" == "https:"  || "$raw" == "http:"  ]]; then
            joined="$raw"
            continue
        fi

        echo "$raw"
    done
    [[ -n "$joined" ]] && echo "$joined"
}

# ── Normalise a single URL ───────────────────────────────────
normalize_url() {
    local url="$1"
    url="$(echo "$url" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -z "$url" ]] && return
    # Heal paste artefacts like "https:/ /" → "https://"
    url="$(echo "$url" | sed 's|https:/[[:space:]]*/|https://|g; s|http:/[[:space:]]*/|http://|g')"
    # Add scheme if missing
    [[ "$url" != http://* && "$url" != https://* ]] && url="https://$url"
    # Force https
    url="${url/http:\/\//https://}"
    echo "$url"
}

# ── Detect platform ──────────────────────────────────────────
detect_platform() {
    local url="$1"
    case "$url" in
        *facebook.com*|*fb.watch*)         echo "Facebook" ;;
        *youtube.com*|*youtu.be*)          echo "YouTube" ;;
        *instagram.com*)                   echo "Instagram" ;;
        *tiktok.com*)                      echo "TikTok" ;;
        *twitter.com*|*x.com*)             echo "Twitter/X" ;;
        *reddit.com*|*redd.it*)            echo "Reddit" ;;
        *pinterest.com*|*pin.it*)          echo "Pinterest" ;;
        *vimeo.com*)                       echo "Vimeo" ;;
        *dailymotion.com*)                 echo "Dailymotion" ;;
        *linkedin.com*)                    echo "LinkedIn" ;;
        *twitch.tv*)                       echo "Twitch" ;;
        *streamable.com*)                  echo "Streamable" ;;
        *rumble.com*)                      echo "Rumble" ;;
        *odysee.com*)                      echo "Odysee" ;;
        *)                                 echo "Web" ;;
    esac
}

# Rebuild with healed URLs
HEALED=()
while IFS= read -r line; do
    HEALED+=("$line")
done < <(heal_and_split_urls)
RAW_INPUT=("${HEALED[@]}")

echo ""
echo -e "  ${WHITE}Normalising URLs...${NC}"
echo ""

CLEAN_URLS=()
SEEN_URLS=()
DUPES=0
INVALID=0

for raw in "${RAW_INPUT[@]}"; do
    [[ -z "$raw" || "$raw" == \#* ]] && continue

    norm="$(normalize_url "$raw")"
    [[ -z "$norm" ]] && continue

    # Basic validity check
    if ! [[ "$norm" =~ ^https://[^[:space:]]+\.[^[:space:]]+ ]]; then
        echo -e "  ${RED}✘ Invalid:${NC} ${DIM}$raw${NC}"
        ((INVALID++))
        continue
    fi

    # Deduplicate
    if [[ " ${SEEN_URLS[*]} " == *" $norm "* ]]; then
        echo -e "  ${YELLOW}⊘ Duplicate removed:${NC} ${DIM}$norm${NC}"
        ((DUPES++))
        continue
    fi

    SEEN_URLS+=("$norm")
    CLEAN_URLS+=("$norm")
    PLATFORM="$(detect_platform "$norm")"
    echo -e "  ${GREEN}✔${NC} ${CYAN}[$PLATFORM]${NC} ${DIM}$norm${NC}"
done

echo ""
echo -e "  ${BOLD}${#CLEAN_URLS[@]} URL(s) queued${NC}${DIM} · $DUPES duplicate(s) removed · $INVALID invalid${NC}"

if [ ${#CLEAN_URLS[@]} -eq 0 ]; then
    echo -e "  ${RED}✘ Nothing to download. Exiting.${NC}"
    exit 1
fi

echo ""
echo -e "${DIM}  ─────────────────────────────────────────────────────${NC}"
echo ""

# ════════════════════════════════════════════════════════════
# STEP 6 — DOWNLOAD ENGINE
# ════════════════════════════════════════════════════════════
echo -e "${CYAN}[6/6] DOWNLOADING${NC} — Starting..."
echo ""
echo -e "  ${DIM}Saving to: $SAVE_DIR${NC}"
echo ""

> "$FAILED_FILE"   # Clear old failed list for this run

SUCCESS=0; FAILED=0
FAILED_URLS=()
TOTAL=${#CLEAN_URLS[@]}
INDEX=0

# ── Output filename template ─────────────────────────────────
OUT_TMPL="$SAVE_DIR/%(upload_date>%Y-%m-%d)s_%(uploader).30s_%(title).50s.%(ext)s"

# ── Core download function ───────────────────────────────────
download_url() {
    local url="$1"
    local index="$2"
    local platform="$(detect_platform "$url")"

    echo -e "  ${CYAN}[$index/$TOTAL]${NC} ${WHITE}${BOLD}$platform${NC}"
    echo -e "  ${DIM}$url${NC}"
    echo ""

    # ── Base yt-dlp arguments ────────────────────────────────
    local BASE_ARGS=(
        "${FORMAT_ARGS[@]}"
        "--merge-output-format" "$FORMAT_MERGE"
        "--no-playlist"
        "--retries"          "$MAX_RETRIES"
        "--fragment-retries" "$MAX_RETRIES"
        "--retry-sleep"      "3"
        "--file-access-retries" "3"
        "--extractor-retries"   "3"
        "--socket-timeout"   "30"
        "--output"           "$OUT_TMPL"
        "--add-metadata"
        "--embed-thumbnail"
        "--no-overwrites"
        "--windows-filenames"
        "--no-warnings"
        "--newline"
    )

    # Attach cookies if configured
    [ ${#COOKIE_ARGS[@]} -gt 0 ] && BASE_ARGS+=("${COOKIE_ARGS[@]}")

    # ── Platform-specific tweaks ─────────────────────────────
    case "$platform" in
        Facebook)
            BASE_ARGS+=(
                "--add-header" "Accept-Language:en-US,en;q=0.9"
                "--add-header" "Accept:text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
            )
            ;;
        YouTube)
            BASE_ARGS+=("--prefer-free-formats")
            ;;
        Instagram)
            BASE_ARGS+=("--add-header" "Accept-Language:en-US,en;q=0.9")
            ;;
        TikTok)
            # Attempts to bypass watermark
            BASE_ARGS+=("--extractor-args" "tiktok:api_hostname=api22-normal-c-useast2a.tiktokv.com")
            ;;
        Pinterest)
            # Pinterest videos are often hosted on CDNs — pinit and
            # video.pinimg.com — yt-dlp handles them but needs the
            # full pin URL, not just a board/profile link.
            BASE_ARGS+=(
                "--add-header" "Accept-Language:en-US,en;q=0.9"
                "--add-header" "Referer:https://www.pinterest.com/"
            )
            ;;
        Twitter/X)
            BASE_ARGS+=("--add-header" "Accept-Language:en-US,en;q=0.9")
            ;;
        Reddit)
            # Reddit video+audio are on separate streams
            BASE_ARGS+=("--add-header" "Accept-Language:en-US,en;q=0.9")
            ;;
    esac

    # ════════════════════════════════════════════════════════
    # ATTEMPT 1 — Full quality direct download
    # ════════════════════════════════════════════════════════
    echo -e "  ${DIM}  ▶ Attempt 1/4 — direct download...${NC}"
    yt-dlp "${BASE_ARGS[@]}" --quiet "$url" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✔ Done${NC}"
        log "SUCCESS [attempt1]: $url"
        return 0
    fi

    # ════════════════════════════════════════════════════════
    # ATTEMPT 2 — Simpler format fallback
    # ════════════════════════════════════════════════════════
    echo -e "  ${YELLOW}  ▶ Attempt 2/4 — fallback format...${NC}"
    local FALLBACK_ARGS=(
        "-f" "best/bestvideo+bestaudio"
        "--merge-output-format" "$FORMAT_MERGE"
        "--no-playlist"
        "--retries"        "$MAX_RETRIES"
        "--socket-timeout" "30"
        "--output"         "$OUT_TMPL"
        "--no-overwrites"
        "--windows-filenames"
        "--no-warnings"
        "--quiet"
    )
    [ ${#COOKIE_ARGS[@]} -gt 0 ] && FALLBACK_ARGS+=("${COOKIE_ARGS[@]}")

    yt-dlp "${FALLBACK_ARGS[@]}" "$url" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✔ Done (fallback format)${NC}"
        log "SUCCESS [attempt2-fallback]: $url"
        return 0
    fi

    # ════════════════════════════════════════════════════════
    # ATTEMPT 3 — Force saved cookies.txt
    # ════════════════════════════════════════════════════════
    if [ -f "$COOKIES_FILE" ] && [ "$COOKIE_CHOICE" != "1" ]; then
        echo -e "  ${YELLOW}  ▶ Attempt 3/4 — saved cookies.txt...${NC}"
        yt-dlp "${FALLBACK_ARGS[@]}" \
            --cookies "$COOKIES_FILE" \
            --quiet "$url" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "  ${GREEN}✔ Done (saved cookies)${NC}"
            log "SUCCESS [attempt3-cookies]: $url"
            return 0
        fi
    fi

    # ════════════════════════════════════════════════════════
    # ATTEMPT 4 — Try Firefox browser cookies
    # ════════════════════════════════════════════════════════
    if [ "$COOKIE_CHOICE" != "2" ]; then
        echo -e "  ${YELLOW}  ▶ Attempt 4/4 — Firefox browser cookies...${NC}"
        yt-dlp "${FALLBACK_ARGS[@]}" \
            --cookies-from-browser firefox \
            --quiet "$url" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "  ${GREEN}✔ Done (Firefox cookies)${NC}"
            log "SUCCESS [attempt4-firefox]: $url"
            return 0
        fi
    fi

    # ════════════════════════════════════════════════════════
    # ALL ATTEMPTS FAILED
    # ════════════════════════════════════════════════════════
    echo -e "  ${RED}✘ Failed after 4 attempts${NC}"
    log "FAILED: $url"
    echo "$url" >> "$FAILED_FILE"
    return 1
}

# ── Run the queue ────────────────────────────────────────────
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
echo -e "  ${GREEN}✔ Successful : $SUCCESS / $TOTAL${NC}"
[ $FAILED -gt 0 ] && echo -e "  ${RED}✘ Failed     : $FAILED / $TOTAL${NC}"
echo -e "  ${CYAN}📁 Saved to  : $SAVE_DIR${NC}"
echo -e "  ${DIM}📋 Log       : $LOG_FILE${NC}"
echo ""

if [ ${#FAILED_URLS[@]} -gt 0 ]; then
    echo -e "${YELLOW}  Failed URLs (auto-queued for next run):${NC}"
    for u in "${FAILED_URLS[@]}"; do
        echo -e "  ${DIM}  → $u${NC}"
    done
    echo ""
    echo -e "${DIM}  ─────────────────────────────────────────────────────"
    echo -e "  TROUBLESHOOTING:"
    echo ""
    echo -e "  Facebook reels / private videos:"
    echo -e "    → Open Firefox → install 'cookies.txt' add-on"
    echo -e "    → Log into Facebook → Export cookies → save to Downloads"
    echo -e "    → Re-run RENON → choose [4] → /sdcard/Download/cookies.txt"
    echo ""
    echo -e "  Pinterest videos:"
    echo -e "    → Use full pin URL: https://www.pinterest.com/pin/12345..."
    echo -e "    → Short links (pin.it/xxx) also work"
    echo -e "    → Log into Pinterest in Firefox and use cookies for saves"
    echo ""
    echo -e "  YouTube age-restricted:"
    echo -e "    → Log into YouTube in Firefox → use option [2] cookies"
    echo ""
    echo -e "  To retry all failed URLs:"
    echo -e "    → Just run RENON again — it will offer the failed list${NC}"
    echo ""
fi

echo -e "${DIM}  ═════════════════════════════════════════════════════${NC}"
echo ""
log "RUN COMPLETE — success=$SUCCESS failed=$FAILED total=$TOTAL"
