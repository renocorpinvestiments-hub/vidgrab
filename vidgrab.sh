#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
#  VIDGRAB v2 — Termux Bulk Video Downloader
#  Supports: Facebook, YouTube, Instagram, TikTok, Twitter/X
#            Reddit, Vimeo, Dailymotion, LinkedIn & more
# ============================================================

# ── Colours ─────────────────────────────────────────────────
RED='\033[0;31m';    GREEN='\033[0;32m'
YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BLUE='\033[0;34m';   MAGENTA='\033[0;35m'
WHITE='\033[1;37m';  DIM='\033[2m';  NC='\033[0m'

# ── Config ───────────────────────────────────────────────────
SAVE_DIR="$HOME/storage/downloads/VidGrab"
COOKIES_DIR="$HOME/.config/vidgrab"
COOKIES_FILE="$COOKIES_DIR/cookies.txt"
LOG_FILE="$COOKIES_DIR/vidgrab.log"
FAILED_FILE="$COOKIES_DIR/failed_urls.txt"
MAX_RETRIES=4
CONCURRENT=2           # how many downloads at once
MAX_HEIGHT=1080        # max video quality

mkdir -p "$COOKIES_DIR"

# ── Logging ──────────────────────────────────────────────────
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

# ── Banner ───────────────────────────────────────────────────
clear
echo -e "${CYAN}"
echo "  ██╗   ██╗██╗██████╗  ██████╗ ██████╗  █████╗ ██████╗ "
echo "  ██║   ██║██║██╔══██╗██╔════╝ ██╔══██╗██╔══██╗██╔══██╗"
echo "  ██║   ██║██║██║  ██║██║  ███╗██████╔╝███████║██████╔╝"
echo "  ╚██╗ ██╔╝██║██║  ██║██║   ██║██╔══██╗██╔══██║██╔══██╗"
echo "   ╚████╔╝ ██║██████╔╝╚██████╔╝██║  ██║██║  ██║██████╔╝"
echo "    ╚═══╝  ╚═╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝"
echo -e "${NC}${DIM}  v2 — Multi-source · Cookie auth · Auto-retry · Bulk${NC}"
echo ""
echo -e "${DIM}  ───────────────────────────────────────────────────────${NC}"
echo ""

# ════════════════════════════════════════════════════════════
# STEP 1 — DEPENDENCIES
# ════════════════════════════════════════════════════════════
echo -e "${CYAN}[1/6] SETUP${NC} — Checking dependencies..."
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
        echo -e "  ${GREEN}✔ $pkg${NC}${DIM} already ready${NC}"
    fi
}

pkg_install python python3
pkg_install ffmpeg ffmpeg
pkg_install curl curl
pkg_install wget wget
pkg_install jq jq
pkg_install openssl openssl

# yt-dlp — install or upgrade
if ! command -v yt-dlp &>/dev/null; then
    echo -e "  ${YELLOW}⬇ Installing yt-dlp...${NC}"
    pip install -q yt-dlp && echo -e "  ${GREEN}✔ yt-dlp installed${NC}"
else
    echo -e "  ${YELLOW}↑ Upgrading yt-dlp (keeps Facebook/YouTube working)...${NC}"
    pip install -q --upgrade yt-dlp 2>/dev/null \
        && echo -e "  ${GREEN}✔ yt-dlp up to date${NC}" \
        || echo -e "  ${DIM}  yt-dlp upgrade skipped (offline?)${NC}"
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
echo -e "  ${DIM}Save folder: $SAVE_DIR${NC}"
echo ""
echo -e "${DIM}  ───────────────────────────────────────────────────────${NC}"
echo ""

# ════════════════════════════════════════════════════════════
# STEP 2 — INTERNET CHECK
# ════════════════════════════════════════════════════════════
echo -e "${CYAN}[2/6] NETWORK${NC} — Checking internet..."
echo ""

check_internet() {
    local hosts=("google.com" "cloudflare.com" "1.1.1.1")
    for h in "${hosts[@]}"; do
        if curl -s --max-time 4 --head "https://$h" &>/dev/null; then
            return 0
        fi
    done
    return 1
}

if check_internet; then
    echo -e "  ${GREEN}✔ Internet connected${NC}"
    # Check latency
    LATENCY=$(curl -s -o /dev/null -w "%{time_total}" --max-time 5 https://google.com 2>/dev/null)
    echo -e "  ${DIM}  Latency: ${LATENCY}s${NC}"
else
    echo -e "  ${RED}✘ No internet. Connect to WiFi or data and retry.${NC}"
    log "ABORT: no internet"
    exit 1
fi

echo ""
echo -e "${DIM}  ───────────────────────────────────────────────────────${NC}"
echo ""

# ════════════════════════════════════════════════════════════
# STEP 3 — COOKIE SETUP
# ════════════════════════════════════════════════════════════
echo -e "${CYAN}[3/6] COOKIES${NC} — Authentication for private/restricted videos"
echo ""
echo -e "  ${DIM}Cookies let VidGrab download videos that need login"
echo -e "  (Facebook reels, private posts, age-restricted YouTube, etc.)${NC}"
echo ""
echo -e "  ${WHITE}Choose cookie method:${NC}"
echo ""
echo -e "  ${GREEN}[1]${NC} Use existing cookies file ${DIM}($COOKIES_FILE)${NC}"
echo -e "  ${GREEN}[2]${NC} Export cookies from Firefox (recommended)"
echo -e "  ${GREEN}[3]${NC} Export cookies from Chrome"
echo -e "  ${GREEN}[4]${NC} Paste a Netscape cookies.txt file path manually"
echo -e "  ${GREEN}[5]${NC} Skip cookies ${DIM}(public videos only)${NC}"
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
            echo -e "  ${YELLOW}⚠ No cookies file found at $COOKIES_FILE${NC}"
            echo -e "  ${DIM}  Continuing without cookies.${NC}"
        fi
        ;;
    2)
        echo -e "  ${YELLOW}Exporting Firefox cookies...${NC}"
        echo -e "  ${DIM}  Make sure Firefox is CLOSED before proceeding.${NC}"
        sleep 1
        yt-dlp --cookies-from-browser firefox --skip-download \
            "https://www.youtube.com" -o /dev/null 2>/dev/null \
            && COOKIE_ARGS=("--cookies-from-browser" "firefox") \
            && echo -e "  ${GREEN}✔ Firefox cookies ready${NC}" \
            || echo -e "  ${RED}✘ Firefox cookies failed — is Firefox installed?${NC}"
        ;;
    3)
        echo -e "  ${YELLOW}Exporting Chrome cookies...${NC}"
        echo -e "  ${DIM}  Make sure Chrome is CLOSED before proceeding.${NC}"
        sleep 1
        yt-dlp --cookies-from-browser chrome --skip-download \
            "https://www.youtube.com" -o /dev/null 2>/dev/null \
            && COOKIE_ARGS=("--cookies-from-browser" "chrome") \
            && echo -e "  ${GREEN}✔ Chrome cookies ready${NC}" \
            || echo -e "  ${RED}✘ Chrome cookies failed — is Chrome installed?${NC}"
        ;;
    4)
        read -r -p "  Paste full path to cookies.txt: " CUSTOM_COOKIES
        CUSTOM_COOKIES="${CUSTOM_COOKIES//\'/}"
        if [ -f "$CUSTOM_COOKIES" ]; then
            cp "$CUSTOM_COOKIES" "$COOKIES_FILE"
            COOKIE_ARGS=("--cookies" "$COOKIES_FILE")
            echo -e "  ${GREEN}✔ Cookies loaded from: $CUSTOM_COOKIES${NC}"
        else
            echo -e "  ${RED}✘ File not found: $CUSTOM_COOKIES${NC}"
            echo -e "  ${DIM}  Continuing without cookies.${NC}"
        fi
        ;;
    5|*)
        echo -e "  ${DIM}Skipping cookies — public videos only.${NC}"
        ;;
esac

echo ""
echo -e "${DIM}  ───────────────────────────────────────────────────────${NC}"
echo ""

# ════════════════════════════════════════════════════════════
# STEP 4 — QUALITY / FORMAT CHOICE
# ════════════════════════════════════════════════════════════
echo -e "${CYAN}[4/6] FORMAT${NC} — Choose download quality"
echo ""
echo -e "  ${GREEN}[1]${NC} Best quality MP4 up to 1080p  ${DIM}(recommended)${NC}"
echo -e "  ${GREEN}[2]${NC} Best quality MP4 up to 720p   ${DIM}(saves space)${NC}"
echo -e "  ${GREEN}[3]${NC} Best quality MP4 up to 480p   ${DIM}(slow data)${NC}"
echo -e "  ${GREEN}[4]${NC} Audio only MP3                ${DIM}(music/podcasts)${NC}"
echo -e "  ${GREEN}[5]${NC} Best possible — no limit      ${DIM}(4K if available)${NC}"
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
echo -e "${DIM}  ───────────────────────────────────────────────────────${NC}"
echo ""

# ════════════════════════════════════════════════════════════
# STEP 5 — COLLECT & NORMALISE URLs
# ════════════════════════════════════════════════════════════
echo -e "${CYAN}[5/6] URLs${NC} — Paste your links"
echo ""
echo -e "  ${DIM}• Paste all URLs at once — blank lines are ignored"
echo -e "  • Mix any platforms freely"
echo -e "  • Press ENTER on an empty line when done${NC}"
echo ""

# Also offer to retry previously failed URLs
if [ -f "$FAILED_FILE" ] && [ -s "$FAILED_FILE" ]; then
    FAIL_COUNT=$(wc -l < "$FAILED_FILE")
    echo -e "  ${YELLOW}⚠ Found $FAIL_COUNT previously failed URL(s)${NC}"
    read -r -p "  Add them to this batch? [y/N]: " ADD_FAILED
    if [[ "$ADD_FAILED" =~ ^[Yy]$ ]]; then
        echo -e "  ${GREEN}✔ Previous failures added${NC}"
        PREFILL=$(cat "$FAILED_FILE")
    fi
fi

echo ""
RAW_INPUT=()

# Read prefilled failed URLs first
if [ -n "$PREFILL" ]; then
    while IFS= read -r line; do
        [[ -n "$line" ]] && RAW_INPUT+=("$line")
    done <<< "$PREFILL"
fi

# Read new URLs from user
while IFS= read -r line; do
    [[ -z "$line" ]] && break
    RAW_INPUT+=("$line")
done

# ── Normalise ────────────────────────────────────────────────
normalize_url() {
    local url="$1"
    # Trim whitespace and carriage returns
    url="$(echo "$url" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -z "$url" ]] && return
    # Add scheme if missing
    [[ "$url" != http://* && "$url" != https://* ]] && url="https://$url"
    # Force https
    url="${url/http:\/\//https://}"
    echo "$url"
}

detect_platform() {
    local url="$1"
    case "$url" in
        *facebook.com*|*fb.watch*)    echo "Facebook" ;;
        *youtube.com*|*youtu.be*)     echo "YouTube" ;;
        *instagram.com*)              echo "Instagram" ;;
        *tiktok.com*)                 echo "TikTok" ;;
        *twitter.com*|*x.com*)        echo "Twitter/X" ;;
        *reddit.com*|*redd.it*)       echo "Reddit" ;;
        *vimeo.com*)                  echo "Vimeo" ;;
        *dailymotion.com*)            echo "Dailymotion" ;;
        *linkedin.com*)               echo "LinkedIn" ;;
        *twitch.tv*)                  echo "Twitch" ;;
        *streamable.com*)             echo "Streamable" ;;
        *)                            echo "Web" ;;
    esac
}

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

    # Basic validity
    if ! [[ "$norm" =~ ^https://[^[:space:]]+\.[^[:space:]]+ ]]; then
        echo -e "  ${RED}✘ Invalid:${NC} ${DIM}$raw${NC}"
        ((INVALID++))
        continue
    fi

    # Deduplicate
    if [[ " ${SEEN_URLS[*]} " == *" $norm "* ]]; then
        echo -e "  ${YELLOW}⊘ Duplicate:${NC} ${DIM}$norm${NC}"
        ((DUPES++))
        continue
    fi

    SEEN_URLS+=("$norm")
    CLEAN_URLS+=("$norm")
    PLATFORM="$(detect_platform "$norm")"
    echo -e "  ${GREEN}✔${NC} ${CYAN}[$PLATFORM]${NC} ${DIM}$norm${NC}"
done

echo ""
echo -e "  ${WHITE}${#CLEAN_URLS[@]} URL(s) ready${NC}${DIM} · $DUPES duplicate(s) removed · $INVALID invalid${NC}"

if [ ${#CLEAN_URLS[@]} -eq 0 ]; then
    echo -e "  ${RED}✘ Nothing to download.${NC}"
    exit 1
fi

echo ""
echo -e "${DIM}  ───────────────────────────────────────────────────────${NC}"
echo ""

# ════════════════════════════════════════════════════════════
# STEP 6 — DOWNLOAD ENGINE
# ════════════════════════════════════════════════════════════
echo -e "${CYAN}[6/6] DOWNLOADING${NC} — Starting..."
echo ""
echo -e "  ${DIM}Saving to: $SAVE_DIR${NC}"
echo ""

# Clear old failed list for this run
> "$FAILED_FILE"

SUCCESS=0
FAILED=0
SKIPPED_DL=0
FAILED_URLS=()
TOTAL=${#CLEAN_URLS[@]}
INDEX=0

# ── Core download function ───────────────────────────────────
download_url() {
    local url="$1"
    local index="$2"
    local platform="$(detect_platform "$url")"

    echo -e "  ${CYAN}[$index/$TOTAL]${NC} ${WHITE}$platform${NC}"
    echo -e "  ${DIM}$url${NC}"

    # Build output template
    local OUT_TMPL="$SAVE_DIR/%(upload_date>%Y-%m-%d)s_%(uploader).30s_%(title).50s.%(ext)s"

    # Base yt-dlp args
    local BASE_ARGS=(
        "${FORMAT_ARGS[@]}"
        "--merge-output-format" "$FORMAT_MERGE"
        "--no-playlist"
        "--retries" "$MAX_RETRIES"
        "--fragment-retries" "$MAX_RETRIES"
        "--retry-sleep" "3"
        "--file-access-retries" "3"
        "--extractor-retries" "3"
        "--socket-timeout" "30"
        "--output" "$OUT_TMPL"
        "--add-metadata"
        "--embed-thumbnail"
        "--write-info-json"
        "--no-overwrites"
        "--windows-filenames"
        "--no-warnings"
        "--newline"
    )

    # Add cookies if configured
    if [ ${#COOKIE_ARGS[@]} -gt 0 ]; then
        BASE_ARGS+=("${COOKIE_ARGS[@]}")
    fi

    # Platform-specific tweaks
    case "$platform" in
        Facebook)
            # Facebook often needs extra headers
            BASE_ARGS+=(
                "--add-header" "Accept-Language:en-US,en;q=0.9"
                "--add-header" "Accept:text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
            )
            ;;
        YouTube)
            # YouTube: prefer VP9/AVC for compatibility
            BASE_ARGS+=("--prefer-free-formats")
            ;;
        Instagram)
            BASE_ARGS+=("--add-header" "Accept-Language:en-US,en;q=0.9")
            ;;
        TikTok)
            # TikTok: bypass watermark when possible
            BASE_ARGS+=("--extractor-args" "tiktok:api_hostname=api22-normal-c-useast2a.tiktokv.com")
            ;;
    esac

    # ── Attempt 1: Normal download ───────────────────────────
    echo -e "  ${DIM}  Attempt 1/3: direct download...${NC}"
    if yt-dlp "${BASE_ARGS[@]}" "$url" 2>&1 | \
        grep -E "^\[download\]|%|Merging|Destination|ERROR" | \
        while IFS= read -r l; do echo -e "  ${DIM}  $l${NC}"; done
    then
        # Check actual exit code via subshell
        yt-dlp "${BASE_ARGS[@]}" --quiet "$url" 2>/dev/null
        local EC=$?
        if [ $EC -eq 0 ]; then
            echo -e "  ${GREEN}✔ Done${NC}"
            log "SUCCESS: $url"
            return 0
        fi
    fi

    # ── Attempt 2: Try without format merging (stream-only) ──
    echo -e "  ${YELLOW}  Attempt 2/3: fallback format...${NC}"
    local FALLBACK_ARGS=(
        "-f" "best/bestvideo+bestaudio"
        "--merge-output-format" "$FORMAT_MERGE"
        "--no-playlist"
        "--retries" "$MAX_RETRIES"
        "--socket-timeout" "30"
        "--output" "$OUT_TMPL"
        "--no-overwrites"
        "--windows-filenames"
        "--no-warnings"
        "--quiet"
    )
    [ ${#COOKIE_ARGS[@]} -gt 0 ] && FALLBACK_ARGS+=("${COOKIE_ARGS[@]}")

    yt-dlp "${FALLBACK_ARGS[@]}" "$url" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✔ Done (fallback format)${NC}"
        log "SUCCESS (fallback): $url"
        return 0
    fi

    # ── Attempt 3: Try with Firefox cookies if not already ───
    if [ "$COOKIE_CHOICE" != "2" ]; then
        echo -e "  ${YELLOW}  Attempt 3/3: trying Firefox cookies...${NC}"
        yt-dlp "${FALLBACK_ARGS[@]}" \
            --cookies-from-browser firefox \
            --quiet "$url" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "  ${GREEN}✔ Done (Firefox cookies)${NC}"
            log "SUCCESS (firefox cookies): $url"
            return 0
        fi
    fi

    # ── All attempts failed ──────────────────────────────────
    echo -e "  ${RED}✘ Failed after all attempts${NC}"
    log "FAILED: $url"
    echo "$url" >> "$FAILED_FILE"
    return 1
}

# ── Run downloads ────────────────────────────────────────────
for url in "${CLEAN_URLS[@]}"; do
    ((INDEX++))
    echo -e "${DIM}  ·······················································${NC}"

    download_url "$url" "$INDEX"
    EC=$?

    if [ $EC -eq 0 ]; then
        ((SUCCESS++))
    else
        ((FAILED++))
        FAILED_URLS+=("$url")
    fi

    echo ""
done

# ════════════════════════════════════════════════════════════
# SUMMARY
# ════════════════════════════════════════════════════════════
echo -e "${DIM}  ═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${WHITE}DOWNLOAD COMPLETE${NC}"
echo ""
echo -e "  ${GREEN}✔ Successful  : $SUCCESS / $TOTAL${NC}"
[ $FAILED -gt 0 ] && echo -e "  ${RED}✘ Failed      : $FAILED / $TOTAL${NC}"
echo -e "  ${CYAN}📁 Saved to   : $SAVE_DIR${NC}"
echo -e "  ${DIM}📋 Log file   : $LOG_FILE${NC}"
echo ""

if [ ${#FAILED_URLS[@]} -gt 0 ]; then
    echo -e "${YELLOW}  Failed URLs (saved to $FAILED_FILE):${NC}"
    for u in "${FAILED_URLS[@]}"; do
        echo -e "  ${DIM}  → $u${NC}"
    done
    echo ""
    echo -e "${DIM}  ───────────────────────────────────────────────────────"
    echo -e "  TIPS FOR FAILED VIDEOS:"
    echo ""
    echo -e "  Facebook reels/private videos:"
    echo -e "    1. Open Facebook in Firefox on your phone"
    echo -e "    2. Log in to your account"
    echo -e "    3. Re-run VidGrab and choose option [2] Firefox cookies"
    echo ""
    echo -e "  Age-restricted YouTube:"
    echo -e "    Log into YouTube in Firefox then use Firefox cookies"
    echo ""
    echo -e "  To retry only failed URLs:"
    echo -e "    bash vidgrab.sh   (it will auto-offer the failed list)${NC}"
    echo ""
fi

echo -e "${DIM}  ═══════════════════════════════════════════════════════${NC}"
echo ""

log "RUN COMPLETE — success=$SUCCESS failed=$FAILED total=$TOTAL"
