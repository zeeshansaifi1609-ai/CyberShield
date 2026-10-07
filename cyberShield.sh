#!/usr/bin/env bash
# =============================================================================
# CyberShield - Defensive Cybersecurity Toolkit
# Version: 1.0.0
# Purpose: Authorized defensive security checks and local system diagnostics.
# =============================================================================

set -u
IFS=$'\n\t'

APP_NAME="CyberShield"
APP_VERSION="1.0.0"
REPORT_DIR="${HOME}/cybershield-reports"
LOG_FILE="${REPORT_DIR}/cybershield.log"
LAST_REPORT=""

# -----------------------------------------------------------------------------
# Terminal colors
# -----------------------------------------------------------------------------
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    WHITE='\033[1;37m'
    GRAY='\033[0;90m'
    RESET='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    MAGENTA=''
    CYAN=''
    WHITE=''
    GRAY=''
    RESET=''
fi

# -----------------------------------------------------------------------------
# Initialization
# -----------------------------------------------------------------------------
init() {
    mkdir -p "$REPORT_DIR" 2>/dev/null || true
    touch "$LOG_FILE" 2>/dev/null || true
    log "CyberShield started - version ${APP_VERSION}"
}

log() {
    local message="$1"
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$message" >> "$LOG_FILE" 2>/dev/null || true
}

pause_screen() {
    printf '\n'
    read -r -p "Press Enter to continue..." _
}

clear_screen() {
    command -v clear >/dev/null 2>&1 && clear || printf '\033c'
}

header() {
    clear_screen
    printf '%b\n' "${CYAN}"
    printf '╔══════════════════════════════════════════════════════════════════╗\n'
    printf '║                         CYBERSHIELD                             ║\n'
    printf '║                  Defensive Security Toolkit                    ║\n'
    printf '╚══════════════════════════════════════════════════════════════════╝\n'
    printf '%b' "${RESET}"
    printf '%bVersion: %s | Reports: %s%b\n\n' "$GRAY" "$APP_VERSION" "$REPORT_DIR" "$RESET"
}

section() {
    printf '\n%b--- %s ---%b\n' "$BLUE" "$1" "$RESET"
}

info() {
    printf '%b[INFO]%b %s\n' "$CYAN" "$RESET" "$1"
}

success() {
    printf '%b[PASS]%b %s\n' "$GREEN" "$RESET" "$1"
}

warning() {
    printf '%b[WARN]%b %s\n' "$YELLOW" "$RESET" "$1"
}

danger() {
    printf '%b[HIGH]%b %s\n' "$RED" "$RESET" "$1"
}

error_msg() {
    printf '%b[ERROR]%b %s\n' "$RED" "$RESET" "$1"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

safe_mktemp() {
    mktemp 2>/dev/null || printf '%s/cybershield_%s.tmp\n' "${TMPDIR:-/tmp}" "$$"
}

# -----------------------------------------------------------------------------
# Dependency information
# -----------------------------------------------------------------------------
show_dependencies() {
    section "Dependency Check"

    local tools=("bash" "sha256sum" "md5sum" "awk" "sed" "grep" "curl")
    local tool
    local missing=0

    for tool in "${tools[@]}"; do
        if command_exists "$tool"; then
            success "$tool is available"
        else
            warning "$tool is not installed"
            missing=$((missing + 1))
        fi
    done

    if (( missing == 0 )); then
        success "All recommended dependencies are available."
    else
        warning "$missing recommended dependency/dependencies are missing."
    fi
}

# -----------------------------------------------------------------------------
# Assessment tool installation / wrappers
# -----------------------------------------------------------------------------
install_assessment_tools() {
    header
    section "Install Security Assessment Tools"

    printf '%bThis installs common security assessment utilities for authorized testing only.%b\n\n' "$YELLOW" "$RESET"

    if [[ "$(id -u 2>/dev/null || printf '0')" -ne 0 ]]; then
        warning "Root or sudo access is required to install packages."
        pause_screen
        return
    fi

    local package_list=(nmap nikto hydra sqlmap)
    local missing=()
    local pkg

    for pkg in "${package_list[@]}"; do
        if ! command_exists "$pkg"; then
            missing+=("$pkg")
        fi
    done

    if (( ${#missing[@]} == 0 )); then
        success "All assessment tools are already installed."
        pause_screen
        return
    fi

    printf 'Installing: %s\n' "${missing[*]}"

    if command_exists apt-get; then
        DEBIAN_FRONTEND=noninteractive apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing[@]}"
    elif command_exists yum; then
        yum install -y "${missing[@]}"
    elif command_exists dnf; then
        dnf install -y "${missing[@]}"
    elif command_exists pacman; then
        pacman -S --noconfirm "${missing[@]}"
    else
        warning "No supported package manager was found on this system."
        pause_screen
        return
    fi

    success "Assessment tool installation completed."
    log "Assessment tools installation attempted"
    pause_screen
}

run_nmap_scan() {
    header
    section "Nmap Port Scan"

    read -r -p "Enter an authorized target host or IP: " target
    if [[ -z "$target" ]]; then
        error_msg "No target supplied."
        pause_screen
        return
    fi

    if ! command_exists nmap; then
        warning "nmap is not installed. Use the assessment tool install option first."
        pause_screen
        return
    fi

    printf '%bScanning %s with nmap...%b\n\n' "$YELLOW" "$target" "$RESET"
    nmap -sS -sV -A -T4 "$target" -oN "$REPORT_DIR/nmap_scan.txt"
    log "Nmap scan executed against ${target}"
    pause_screen
}

run_nikto_scan() {
    header
    section "Nikto Web Scanner"

    read -r -p "Enter an authorized website URL: " target
    if [[ -z "$target" ]]; then
        error_msg "No URL supplied."
        pause_screen
        return
    fi

    if ! command_exists nikto; then
        warning "nikto is not installed. Use the assessment tool install option first."
        pause_screen
        return
    fi

    local url
    url="$(normalize_url "$target")"
    printf '%bScanning %s with Nikto...%b\n\n' "$YELLOW" "$url" "$RESET"
    nikto -h "$url" -output "$REPORT_DIR/nikto_scan.txt"
    log "Nikto scan executed for ${url}"
    pause_screen
}

run_hydra_scan() {
    header
    section "Hydra Credential Tester"

    printf '%bThis module is for authorized credential testing against your own targets only.%b\n\n' "$YELLOW" "$RESET"

    if ! command_exists hydra; then
        warning "hydra is not installed. Use the assessment tool install option first."
        pause_screen
        return
    fi

    read -r -p "Target host: " target
    read -r -p "Service (ssh/ftp/http-post-form): " service
    read -r -p "Username list: " userlist
    read -r -p "Password list: " passlist

    if [[ -z "$target" || -z "$service" || -z "$userlist" || -z "$passlist" ]]; then
        error_msg "Target, service, user list, and password list are required."
        pause_screen
        return
    fi

    if [[ ! -f "$userlist" || ! -f "$passlist" ]]; then
        error_msg "The provided wordlist paths do not exist."
        pause_screen
        return
    fi

    printf '%bRunning Hydra against %s on %s...%b\n\n' "$YELLOW" "$target" "$service" "$RESET"
    hydra -L "$userlist" -P "$passlist" "$target" "$service" -o "$REPORT_DIR/hydra_scan.txt"
    log "Hydra scan executed against ${target} using ${service}"
    pause_screen
}

run_sqlmap_scan() {
    header
    section "SQLMap Scanner"

    if ! command_exists sqlmap; then
        warning "sqlmap is not installed. Use the assessment tool install option first."
        pause_screen
        return
    fi

    read -r -p "Enter an authorized target URL to test: " target
    if [[ -z "$target" ]]; then
        error_msg "No target URL supplied."
        pause_screen
        return
    fi

    printf '%bRunning SQLMap against %s...%b\n\n' "$YELLOW" "$target" "$RESET"
    sqlmap -u "$target" --batch --output-dir "$REPORT_DIR/sqlmap"
    log "SQLMap scan executed for ${target}"
    pause_screen
}

# -----------------------------------------------------------------------------
# Banner
# -----------------------------------------------------------------------------
show_banner() {
    clear_screen
    printf '%b' "$CYAN"
    cat <<'BANNER'
   _____      _               _____ _     _      _     _
  / ____|    | |             / ____| |   (_)    | |   | |
 | |    _   _| |__   ___ _ _| (___ | |__  _  ___| | __| |
 | |   | | | | '_ \ / _ \ '__\___ \| '_ \| |/ _ \ |/ _` |
 | |___| |_| | |_) |  __/ |  ____) | | | | |  __/ | (_| |
  \_____\__, |_.__/ \___|_| |_____/|_| |_|_|\___|_|\__,_|
          __/ |
         |___/
BANNER
    printf '%b' "$RESET"
    printf '%b  Defensive Cybersecurity Toolkit v%s%b\n\n' "$WHITE" "$APP_VERSION" "$RESET"
    printf '%bUse only on systems, files, networks, and websites you own or are authorized to assess.%b\n' "$YELLOW" "$RESET"
    sleep 1
}

# -----------------------------------------------------------------------------
# System information
# -----------------------------------------------------------------------------
system_information() {
    header
    section "System Information"

    local hostname_value
    local kernel
    local uptime_value
    local shell_value
    local user_value
    local os_value

    hostname_value="$(hostname 2>/dev/null || printf 'Unknown')"
    kernel="$(uname -sr 2>/dev/null || printf 'Unknown')"
    uptime_value="$(uptime -p 2>/dev/null || uptime 2>/dev/null || printf 'Unknown')"
    shell_value="${SHELL:-Unknown}"
    user_value="${USER:-$(id -un 2>/dev/null || printf 'Unknown')}"

    if [[ -f /etc/os-release ]]; then
        os_value="$(. /etc/os-release && printf '%s %s' "${NAME:-Unknown}" "${VERSION_ID:-}")"
    else
        os_value="$(uname -o 2>/dev/null || printf 'Unknown')"
    fi

    printf 'Hostname : %s\n' "$hostname_value"
    printf 'User     : %s\n' "$user_value"
    printf 'OS       : %s\n' "$os_value"
    printf 'Kernel   : %s\n' "$kernel"
    printf 'Shell    : %s\n' "$shell_value"
    printf 'Uptime   : %s\n' "$uptime_value"

    section "Disk Usage"
    df -h 2>/dev/null | head -n 8 || warning "Disk information unavailable."

    section "Memory"
    if command_exists free; then
        free -h
    else
        warning "The 'free' command is unavailable."
    fi

    log "System information viewed"
    pause_screen
}

# -----------------------------------------------------------------------------
# Network information
# -----------------------------------------------------------------------------
network_information() {
    header
    section "Local Network Information"

    if command_exists ip; then
        printf '%bInterfaces:%b\n' "$WHITE" "$RESET"
        ip -brief address 2>/dev/null || ip addr 2>/dev/null
    elif command_exists ifconfig; then
        ifconfig 2>/dev/null
    else
        warning "No supported network interface command was found."
    fi

    section "Routing Table"
    if command_exists ip; then
        ip route 2>/dev/null || warning "Routing information unavailable."
    elif command_exists route; then
        route -n 2>/dev/null || warning "Routing information unavailable."
    else
        warning "No routing command available."
    fi

    section "DNS Configuration"
    if [[ -f /etc/resolv.conf ]]; then
        grep -E '^[[:space:]]*nameserver' /etc/resolv.conf 2>/dev/null || \
            warning "No nameserver entries found."
    else
        warning "/etc/resolv.conf not found."
    fi

    log "Network information viewed"
    pause_screen
}

# -----------------------------------------------------------------------------
# Active local connections
# -----------------------------------------------------------------------------
connection_monitor() {
    header
    section "Local Connection Monitor"

    info "This module displays connections visible from your own machine."
    printf '\n'

    if command_exists ss; then
        ss -tunap 2>/dev/null || ss -tuna 2>/dev/null
    elif command_exists netstat; then
        netstat -tunap 2>/dev/null || netstat -tuna 2>/dev/null
    else
        warning "Neither ss nor netstat is available."
    fi

    section "Listening Services"
    if command_exists ss; then
        ss -lntup 2>/dev/null || ss -lntu 2>/dev/null
    elif command_exists netstat; then
        netstat -lntup 2>/dev/null || netstat -lntu 2>/dev/null
    else
        warning "Listening-service information unavailable."
    fi

    log "Local connection monitor executed"
    pause_screen
}

# -----------------------------------------------------------------------------
# URL validation
# -----------------------------------------------------------------------------
normalize_url() {
    local value="$1"

    if [[ "$value" != http://* && "$value" != https://* ]]; then
        value="https://${value}"
    fi

    printf '%s' "$value"
}

url_analyzer() {
    header
    section "URL Security Analyzer"

    read -r -p "Enter a URL to analyze: " target

    if [[ -z "$target" ]]; then
        error_msg "No URL supplied."
        pause_screen
        return
    fi

    local url
    url="$(normalize_url "$target")"

    printf '\n%bAnalyzing:%b %s\n\n' "$WHITE" "$RESET" "$url"

    local score=0
    local host=''
    local scheme=''
    local rest=''

    if [[ "$url" =~ ^(https?)://([^/]+)(.*)$ ]]; then
        scheme="${BASH_REMATCH[1]}"
        host="${BASH_REMATCH[2]}"
        rest="${BASH_REMATCH[3]}"
    else
        error_msg "The URL format could not be parsed."
        pause_screen
        return
    fi

    if [[ "$scheme" == "https" ]]; then
        success "HTTPS scheme detected."
    else
        warning "HTTP is being used instead of HTTPS."
        score=$((score + 2))
    fi

    if [[ "$host" == *"@"* ]]; then
        danger "The URL contains an @ character, which can be misleading in URLs."
        score=$((score + 2))
    else
        success "No @ character detected in the hostname portion."
    fi

    if [[ "$host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        warning "The host appears to be an IPv4 address rather than a domain."
        score=$((score + 1))
    else
        success "Hostname is not a plain IPv4 address."
    fi

    local host_length="${#host}"
    if (( host_length > 63 )); then
        warning "Hostname is unusually long (${host_length} characters)."
        score=$((score + 1))
    else
        success "Hostname length looks reasonable."
    fi

    local dash_count
    dash_count="$(printf '%s' "$host" | tr -cd '-' | wc -c | tr -d ' ')"
    if (( dash_count > 4 )); then
        warning "Hostname contains many hyphens."
        score=$((score + 1))
    fi

    if [[ "$host" =~ xn-- ]]; then
        warning "Punycode/IDN encoding detected. Verify the domain carefully."
        score=$((score + 1))
    else
        success "No Punycode marker detected."
    fi

    if [[ "$url" =~ [[:space:]] ]]; then
        danger "Whitespace was detected in the URL."
        score=$((score + 2))
    fi

    printf '\n'
    if (( score == 0 )); then
        success "No basic URL red flags were detected."
    elif (( score <= 2 )); then
        warning "Some URL characteristics deserve review."
    else
        danger "Multiple URL warning indicators were detected."
    fi

    printf 'Heuristic score: %d\n' "$score"
    printf '%bNote:%b This is a heuristic check, not a malware/phishing verdict.\n' "$GRAY" "$RESET"

    log "URL analyzer executed for ${host}"
    pause_screen
}

# -----------------------------------------------------------------------------
# HTTP security headers
# -----------------------------------------------------------------------------
website_header_scanner() {
    header
    section "Website Security Header Scanner"

    read -r -p "Enter an authorized website URL: " target

    if [[ -z "$target" ]]; then
        error_msg "No URL supplied."
        pause_screen
        return
    fi

    if ! command_exists curl; then
        error_msg "curl is required for this module."
        pause_screen
        return
    fi

    local url
    url="$(normalize_url "$target")"

    info "Checking HTTP response headers for: $url"
    printf '%bOnly test websites you own or are authorized to assess.%b\n\n' "$YELLOW" "$RESET"

    local headers_file
    headers_file="$(safe_mktemp)"

    if ! curl -L --max-time 12 --connect-timeout 7 -sS -D "$headers_file" -o /dev/null "$url" 2>/dev/null; then
        error_msg "The website could not be contacted."
        rm -f "$headers_file"
        pause_screen
        return
    fi

    local checks=(
        "strict-transport-security|Strict-Transport-Security"
        "content-security-policy|Content-Security-Policy"
        "x-content-type-options|X-Content-Type-Options"
        "x-frame-options|X-Frame-Options"
        "referrer-policy|Referrer-Policy"
        "permissions-policy|Permissions-Policy"
    )

    local item
    local key
    local label
    local header_lower
    local present=0
    local total=0

    header_lower="$(tr '[:upper:]' '[:lower:]' < "$headers_file")"

    for item in "${checks[@]}"; do
        key="${item%%|*}"
        label="${item#*|}"
        total=$((total + 1))

        if grep -qi "^${key}:" <<< "$header_lower"; then
            success "$label is present."
            present=$((present + 1))
        else
            warning "$label was not observed."
        fi
    done

    printf '\n'
    printf 'Security-header coverage: %d/%d\n' "$present" "$total"

    section "Response Summary"
    head -n 12 "$headers_file" 2>/dev/null

    rm -f "$headers_file"
    log "Website header scanner executed for $url"
    pause_screen
}

# -----------------------------------------------------------------------------
# Cookie flag inspection
# -----------------------------------------------------------------------------
cookie_checker() {
    header
    section "Cookie Security Flag Checker"

    read -r -p "Enter an authorized HTTPS website URL: " target

    if [[ -z "$target" ]]; then
        error_msg "No URL supplied."
        pause_screen
        return
    fi

    if ! command_exists curl; then
        error_msg "curl is required."
        pause_screen
        return
    fi

    local url
    url="$(normalize_url "$target")"
    local headers_file
    headers_file="$(safe_mktemp)"

    if ! curl -L --max-time 12 --connect-timeout 7 -sS -D "$headers_file" -o /dev/null "$url" 2>/dev/null; then
        error_msg "Unable to retrieve headers."
        rm -f "$headers_file"
        pause_screen
        return
    fi

    local cookies
    cookies="$(grep -i '^set-cookie:' "$headers_file" 2>/dev/null || true)"

    if [[ -z "$cookies" ]]; then
        info "No Set-Cookie response headers were observed."
        rm -f "$headers_file"
        pause_screen
        return
    fi

    printf '%s\n' "$cookies"
    printf '\n'

    if grep -qi 'secure' <<< "$cookies"; then
        success "At least one cookie includes the Secure attribute."
    else
        warning "No Secure cookie attribute was observed."
    fi

    if grep -qi 'httponly' <<< "$cookies"; then
        success "At least one cookie includes HttpOnly."
    else
        warning "No HttpOnly cookie attribute was observed."
    fi

    if grep -qi 'samesite' <<< "$cookies"; then
        success "At least one cookie includes SameSite."
    else
        warning "No SameSite attribute was observed."
    fi

    rm -f "$headers_file"
    log "Cookie checker executed for $url"
    pause_screen
}

# -----------------------------------------------------------------------------
# File hashing
# -----------------------------------------------------------------------------
file_hash_analyzer() {
    header
    section "File Hash Analyzer"

    read -r -p "Enter a file path: " file_path

    if [[ -z "$file_path" ]]; then
        error_msg "No file path supplied."
        pause_screen
        return
    fi

    if [[ ! -f "$file_path" ]]; then
        error_msg "File does not exist or is not a regular file."
        pause_screen
        return
    fi

    printf '\n%bFile:%b %s\n' "$WHITE" "$RESET" "$file_path"

    if command_exists stat; then
        stat "$file_path" 2>/dev/null || true
    fi

    printf '\n%bHashes:%b\n' "$WHITE" "$RESET"

    if command_exists sha256sum; then
        printf 'SHA-256: '
        sha256sum "$file_path" | awk '{print $1}'
    else
        warning "sha256sum unavailable."
    fi

    if command_exists sha1sum; then
        printf 'SHA-1  : '
        sha1sum "$file_path" | awk '{print $1}'
    else
        warning "sha1sum unavailable."
    fi

    if command_exists md5sum; then
        printf 'MD5    : '
        md5sum "$file_path" | awk '{print $1}'
    else
        warning "md5sum unavailable."
    fi

    printf '\n%bImportant:%b A hash identifies a file; it does not by itself prove that a file is safe or malicious.\n' "$GRAY" "$RESET"

    log "File hash analyzer executed for $file_path"
    pause_screen
}

# -----------------------------------------------------------------------------
# File permission checker
# -----------------------------------------------------------------------------
file_permission_checker() {
    header
    section "File Permission Checker"

    read -r -p "Enter a file path: " file_path

    if [[ -z "$file_path" || ! -e "$file_path" ]]; then
        error_msg "Path does not exist."
        pause_screen
        return
    fi

    if command_exists stat; then
        local perms
        perms="$(stat -c '%A %a' "$file_path" 2>/dev/null || true)"
        printf 'Permissions: %s\n' "$perms"

        if [[ "$perms" == *"777" ]]; then
            warning "World-readable/writable/executable permissions may be unnecessarily broad."
        else
            success "The path is not using mode 777."
        fi
    else
        warning "stat is unavailable."
    fi

    if [[ -r "$file_path" ]]; then
        success "Current user can read this path."
    else
        warning "Current user cannot read this path."
    fi

    if [[ -w "$file_path" ]]; then
        info "Current user can write this path."
    fi

    if [[ -x "$file_path" ]]; then
        info "Current user can execute this path."
    fi

    log "File permission checker executed for $file_path"
    pause_screen
}

# -----------------------------------------------------------------------------
# Password strength checker
# -----------------------------------------------------------------------------
password_checker() {
    header
    section "Password Strength Checker"

    printf '%bYour input is processed locally by this script and is not uploaded.%b\n' "$GRAY" "$RESET"
    printf '%bDo not enter a real password that you currently use.%b\n\n' "$YELLOW" "$RESET"

    read -r -s -p "Enter a test password: " password
    printf '\n'

    local length="${#password}"
    local score=0

    if (( length >= 12 )); then
        score=$((score + 2))
    elif (( length >= 8 )); then
        score=$((score + 1))
    fi

    [[ "$password" =~ [a-z] ]] && score=$((score + 1))
    [[ "$password" =~ [A-Z] ]] && score=$((score + 1))
    [[ "$password" =~ [0-9] ]] && score=$((score + 1))
    [[ "$password" =~ [^a-zA-Z0-9] ]] && score=$((score + 1))

    printf '\nLength: %d characters\n' "$length"

    if (( length < 8 )); then
        warning "Password is short."
    else
        success "Password length is at least 8 characters."
    fi

    if [[ "$password" =~ ^([a-zA-Z0-9])\1+$ ]]; then
        warning "Password contains a repeated single character pattern."
        score=$((score - 2))
    fi

    local lower
    lower="$(printf '%s' "$password" | tr '[:upper:]' '[:lower:]')"

    case "$lower" in
        password|password1|12345678|123456789|qwerty|qwerty123|admin|letmein)
            warning "Password matches a very common pattern."
            score=$((score - 3))
            ;;
    esac

    if (( score <= 2 )); then
        danger "Overall estimate: weak."
    elif (( score <= 4 )); then
        warning "Overall estimate: moderate."
    else
        success "Overall estimate: stronger."
    fi

    printf '%bThis is a simple educational estimator, not a password-cracking system.%b\n' "$GRAY" "$RESET"

    unset password
    log "Password strength checker executed"
    pause_screen
}

# -----------------------------------------------------------------------------
# Process overview
# -----------------------------------------------------------------------------
process_overview() {
    header
    section "Running Process Overview"

    if command_exists ps; then
        ps aux --sort=-%cpu 2>/dev/null | head -n 16 || ps aux 2>/dev/null | head -n 16
    else
        warning "ps is unavailable."
    fi

    section "High CPU Processes"
    if command_exists ps; then
        ps -eo pid,comm,%cpu,%mem --sort=-%cpu 2>/dev/null | head -n 12 || true
    fi

    log "Process overview executed"
    pause_screen
}

# -----------------------------------------------------------------------------
# Listening port summary
# -----------------------------------------------------------------------------
listening_ports() {
    header
    section "Listening Port Summary"

    info "This checks services listening on your own machine."

    if command_exists ss; then
        ss -lntup 2>/dev/null || ss -lntu 2>/dev/null
    elif command_exists netstat; then
        netstat -lntup 2>/dev/null || netstat -lntu 2>/dev/null
    else
        warning "No supported socket utility was found."
    fi

    printf '\n%bCommon ports worth reviewing:%b\n' "$WHITE" "$RESET"
    printf '22   SSH\n'
    printf '80   HTTP\n'
    printf '443  HTTPS\n'
    printf '3306 MySQL\n'
    printf '5432 PostgreSQL\n'
    printf '6379 Redis\n'
    printf '8080 Alternate HTTP\n'

    log "Listening port summary executed"
    pause_screen
}

# -----------------------------------------------------------------------------
# Local security checks
# -----------------------------------------------------------------------------
local_security_check() {
    header
    section "Local Security Check"

    local findings=0

    if [[ "$(id -u 2>/dev/null)" -eq 0 ]]; then
        warning "The script is running as root."
        findings=$((findings + 1))
    else
        success "The script is not running as root."
    fi

    if [[ -f /etc/passwd ]]; then
        success "/etc/passwd exists."
    else
        warning "/etc/passwd was not found."
        findings=$((findings + 1))
    fi

    if [[ -f /etc/shadow ]]; then
        local shadow_perm
        shadow_perm="$(stat -c '%a' /etc/shadow 2>/dev/null || printf 'unknown')"
        printf 'Shadow file mode: %s\n' "$shadow_perm"
        if [[ "$shadow_perm" == "644" || "$shadow_perm" == "666" || "$shadow_perm" == "777" ]]; then
            danger "Shadow file permissions appear unusually broad."
            findings=$((findings + 1))
        else
            success "Shadow file permissions do not match common overly broad modes."
        fi
    fi

    if command_exists ufw; then
        section "UFW Firewall"
        ufw status 2>/dev/null || true
    elif command_exists firewall-cmd; then
        section "Firewalld"
        firewall-cmd --state 2>/dev/null || true
    else
        warning "No common firewall management command was detected."
    fi

    section "SSH Configuration"
    if [[ -f /etc/ssh/sshd_config ]]; then
        if grep -qi '^[[:space:]]*PermitRootLogin[[:space:]]\+yes' /etc/ssh/sshd_config 2>/dev/null; then
            warning "SSH PermitRootLogin is explicitly enabled."
            findings=$((findings + 1))
        else
            success "No explicit PermitRootLogin yes directive was observed."
        fi
    else
        info "sshd_config not found."
    fi

    printf '\n'
    printf 'Findings requiring review: %d\n' "$findings"

    log "Local security check executed"
    pause_screen
}

# -----------------------------------------------------------------------------
# Environment check
# -----------------------------------------------------------------------------
environment_check() {
    header
    section "Environment Check"

    printf 'Bash version : %s\n' "${BASH_VERSION:-unknown}"
    printf 'Current user : %s\n' "${USER:-unknown}"
    printf 'Home         : %s\n' "${HOME:-unknown}"
    printf 'Working dir  : %s\n' "$(pwd 2>/dev/null || printf 'unknown')"
    printf 'PATH         : %s\n' "${PATH:-unknown}"

    section "Important Commands"
    local commands=("curl" "wget" "git" "python3" "openssl" "ssh" "ip" "ss" "ufw")
    local command_name

    for command_name in "${commands[@]}"; do
        if command_exists "$command_name"; then
            printf '%b%-10s%b available\n' "$GREEN" "$command_name" "$RESET"
        else
            printf '%b%-10s%b missing\n' "$YELLOW" "$command_name" "$RESET"
        fi
    done

    log "Environment check executed"
    pause_screen
}

# -----------------------------------------------------------------------------
# DNS lookup
# -----------------------------------------------------------------------------
dns_lookup() {
    header
    section "DNS Information"

    read -r -p "Enter a domain you are authorized to inspect: " domain

    if [[ -z "$domain" ]]; then
        error_msg "No domain supplied."
        pause_screen
        return
    fi

    if command_exists getent; then
        printf '%bAddress information:%b\n' "$WHITE" "$RESET"
        getent ahosts "$domain" 2>/dev/null || warning "No address information returned."
    elif command_exists nslookup; then
        nslookup "$domain" 2>/dev/null || warning "nslookup failed."
    elif command_exists dig; then
        dig "$domain" 2>/dev/null || warning "dig failed."
    else
        warning "No DNS lookup utility is available."
    fi

    log "DNS lookup executed for $domain"
    pause_screen
}

# -----------------------------------------------------------------------------
# TLS certificate overview
# -----------------------------------------------------------------------------
tls_certificate_check() {
    header
    section "TLS Certificate Overview"

    read -r -p "Enter an HTTPS hostname you are authorized to inspect: " host

    if [[ -z "$host" ]]; then
        error_msg "No hostname supplied."
        pause_screen
        return
    fi

    if ! command_exists openssl; then
        error_msg "openssl is required."
        pause_screen
        return
    fi

    host="${host#https://}"
    host="${host%%/*}"

    info "Retrieving certificate metadata from ${host}:443"

    local cert
    cert="$(printf '' | timeout 12 openssl s_client -connect "${host}:443" -servername "$host" 2>/dev/null | \
        openssl x509 -noout -subject -issuer -dates -fingerprint 2>/dev/null || true)"

    if [[ -z "$cert" ]]; then
        error_msg "Could not retrieve a certificate."
    else
        printf '%s\n' "$cert"
    fi

    log "TLS certificate check executed for $host"
    pause_screen
}

# -----------------------------------------------------------------------------
# Search local logs for common security events
# -----------------------------------------------------------------------------
log_review() {
    header
    section "Local Log Review"

    info "This only examines logs available on the local machine."

    local found=0

    if [[ -f /var/log/auth.log ]]; then
        printf '%bRecent authentication-related entries:%b\n' "$WHITE" "$RESET"
        grep -Ei 'failed|invalid|authentication failure|accepted' /var/log/auth.log 2>/dev/null | tail -n 20 || true
        found=1
    fi

    if [[ -f /var/log/secure ]]; then
        printf '%bRecent security-related entries:%b\n' "$WHITE" "$RESET"
        grep -Ei 'failed|invalid|authentication failure|accepted' /var/log/secure 2>/dev/null | tail -n 20 || true
        found=1
    fi

    if command_exists journalctl; then
        section "Journal Authentication Events"
        journalctl --since "24 hours ago" 2>/dev/null | \
            grep -Ei 'failed password|authentication failure|invalid user' | tail -n 20 || true
        found=1
    fi

    if (( found == 0 )); then
        warning "No supported authentication log source was found."
    fi

    log "Local log review executed"
    pause_screen
}

# -----------------------------------------------------------------------------
# Report helpers
# -----------------------------------------------------------------------------
report_start() {
    local timestamp
    timestamp="$(date '+%Y%m%d_%H%M%S')"
    LAST_REPORT="${REPORT_DIR}/cybershield_report_${timestamp}.txt"

    {
        printf 'CyberShield Security Report\n'
        printf '===========================\n'
        printf 'Generated: %s\n' "$(date)"
        printf 'Host: %s\n' "$(hostname 2>/dev/null || printf 'unknown')"
        printf 'User: %s\n' "${USER:-unknown}"
        printf 'Version: %s\n\n' "$APP_VERSION"
    } > "$LAST_REPORT"

    log "Report started: $LAST_REPORT"
}

report_append() {
    local text="$1"
    [[ -n "$LAST_REPORT" ]] && printf '%s\n' "$text" >> "$LAST_REPORT"
}

generate_report() {
    header
    section "Security Report Generator"

    report_start

    report_append "SYSTEM INFORMATION"
    report_append "------------------"
    report_append "Hostname: $(hostname 2>/dev/null || printf 'unknown')"
    report_append "Kernel: $(uname -sr 2>/dev/null || printf 'unknown')"
    report_append "Uptime: $(uptime -p 2>/dev/null || printf 'unknown')"
    report_append ""

    report_append "NETWORK INFORMATION"
    report_append "-------------------"
    if command_exists ip; then
        ip -brief address 2>/dev/null >> "$LAST_REPORT" || true
        ip route 2>/dev/null >> "$LAST_REPORT" || true
    fi
    report_append ""

    report_append "LISTENING SERVICES"
    report_append "------------------"
    if command_exists ss; then
        ss -lntup 2>/dev/null >> "$LAST_REPORT" || true
    fi
    report_append ""

    report_append "DISK USAGE"
    report_append "----------"
    df -h 2>/dev/null >> "$LAST_REPORT" || true
    report_append ""

    report_append "DEPENDENCY CHECK"
    report_append "----------------"
    local tool
    for tool in bash curl openssl sha256sum ip ss; do
        if command_exists "$tool"; then
            report_append "$tool: available"
        else
            report_append "$tool: missing"
        fi
    done

    report_append ""
    report_append "END OF REPORT"

    success "Report created:"
    printf '%s\n' "$LAST_REPORT"

    log "Security report generated"
    pause_screen
}

view_last_report() {
    header
    section "Last Security Report"

    if [[ -z "$LAST_REPORT" || ! -f "$LAST_REPORT" ]]; then
        local newest
        newest="$(ls -1t "$REPORT_DIR"/cybershield_report_*.txt 2>/dev/null | head -n 1 || true)"
        LAST_REPORT="$newest"
    fi

    if [[ -z "$LAST_REPORT" || ! -f "$LAST_REPORT" ]]; then
        warning "No report exists yet."
        pause_screen
        return
    fi

    cat "$LAST_REPORT"
    pause_screen
}

list_reports() {
    header
    section "Saved Reports"

    local reports
    reports="$(ls -1t "$REPORT_DIR"/cybershield_report_*.txt 2>/dev/null || true)"

    if [[ -z "$reports" ]]; then
        info "No reports found."
    else
        printf '%s\n' "$reports"
    fi

    log "Report list viewed"
    pause_screen
}

# -----------------------------------------------------------------------------
# Quick security audit
# -----------------------------------------------------------------------------
quick_audit() {
    header
    section "Quick Local Security Audit"

    local findings=0

    printf '%b[1/8]%b Checking current user...\n' "$CYAN" "$RESET"
    if [[ "$(id -u 2>/dev/null)" -eq 0 ]]; then
        warning "Running as root."
        findings=$((findings + 1))
    else
        success "Running as a normal user."
    fi

    printf '%b[2/8]%b Checking firewall tools...\n' "$CYAN" "$RESET"
    if command_exists ufw || command_exists firewall-cmd || command_exists nft; then
        success "A firewall management tool is available."
    else
        warning "No common firewall management tool was found."
        findings=$((findings + 1))
    fi

    printf '%b[3/8]%b Checking SSH root login configuration...\n' "$CYAN" "$RESET"
    if [[ -f /etc/ssh/sshd_config ]] && grep -qi '^[[:space:]]*PermitRootLogin[[:space:]]\+yes' /etc/ssh/sshd_config 2>/dev/null; then
        danger "Explicit root SSH login is enabled."
        findings=$((findings + 1))
    else
        success "No explicit root SSH login enablement detected."
    fi

    printf '%b[4/8]%b Checking world-writable files in common temporary locations...\n' "$CYAN" "$RESET"
    local tmp_count=0
    if [[ -d /tmp ]]; then
        tmp_count="$(find /tmp -maxdepth 1 -type f -perm -0002 2>/dev/null | wc -l | tr -d ' ')"
    fi
    if (( tmp_count > 0 )); then
        warning "$tmp_count world-writable file(s) found directly under /tmp."
    else
        success "No world-writable files found directly under /tmp."
    fi

    printf '%b[5/8]%b Checking disk usage...\n' "$CYAN" "$RESET"
    local root_usage
    root_usage="$(df -P / 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $5}')"
    if [[ "$root_usage" =~ ^[0-9]+$ ]]; then
        if (( root_usage >= 90 )); then
            danger "Root filesystem is ${root_usage}% full."
            findings=$((findings + 1))
        elif (( root_usage >= 80 )); then
            warning "Root filesystem is ${root_usage}% full."
        else
            success "Root filesystem usage is ${root_usage}%."
        fi
    else
        warning "Could not determine root filesystem usage."
    fi

    printf '%b[6/8]%b Checking listening services...\n' "$CYAN" "$RESET"
    if command_exists ss; then
        local listener_count
        listener_count="$(ss -lnt 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')"
        info "${listener_count:-0} TCP listening socket(s) observed."
    else
        warning "ss is unavailable."
    fi

    printf '%b[7/8]%b Checking password policy files...\n' "$CYAN" "$RESET"
    if [[ -f /etc/login.defs ]]; then
        success "/etc/login.defs exists."
    else
        warning "/etc/login.defs was not found."
    fi

    printf '%b[8/8]%b Checking time synchronization...\n' "$CYAN" "$RESET"
    if command_exists timedatectl; then
        timedatectl status 2>/dev/null | grep -Ei 'System clock synchronized|NTP service' || true
    else
        info "timedatectl unavailable."
    fi

    printf '\n'
    if (( findings == 0 )); then
        success "Quick audit completed with no high-priority findings from these checks."
    else
        warning "Quick audit completed with ${findings} item(s) requiring review."
    fi

    log "Quick security audit executed"
    pause_screen
}

# -----------------------------------------------------------------------------
# Help
# -----------------------------------------------------------------------------
show_help() {
    header
    section "CyberShield Help"

    cat <<'HELP'
CyberShield is a defensive, local-first security toolkit.

Recommended workflow:
  1. Start with Quick Local Security Audit.
  2. Review your listening services.
  3. Check local logs.
  4. Use URL and website checks only against authorized targets.
  5. Generate a report when finished.

Safety:
  - Only inspect systems and websites you own or have permission to assess.
  - Do not use this tool to obtain credentials or bypass access controls.
  - Hashes identify files but do not prove that a file is malicious.
  - URL heuristics can produce false positives and false negatives.
  - Header checks are configuration indicators, not complete penetration tests.

The tool intentionally avoids:
  - Credential theft
  - Malware deployment
  - Persistence mechanisms
  - Exploit delivery
  - Stealth/evasion features
  - Unauthorized scanning

HELP

    pause_screen
}

# -----------------------------------------------------------------------------
# Main menu
# -----------------------------------------------------------------------------
main_menu() {
    while true; do
        header

        printf '%bDEFENSIVE SECURITY%b\n\n' "$WHITE" "$RESET"
        printf '  %b[1]%b  Quick Local Security Audit\n' "$CYAN" "$RESET"
        printf '  %b[2]%b  System Information\n' "$CYAN" "$RESET"
        printf '  %b[3]%b  Network Information\n' "$CYAN" "$RESET"
        printf '  %b[4]%b  Local Connection Monitor\n' "$CYAN" "$RESET"
        printf '  %b[5]%b  Listening Port Summary\n' "$CYAN" "$RESET"
        printf '  %b[6]%b  Process Overview\n' "$CYAN" "$RESET"
        printf '  %b[7]%b  Local Security Check\n' "$CYAN" "$RESET"
        printf '  %b[8]%b  Local Log Review\n' "$CYAN" "$RESET"
        printf '\n%bWEB / URL ANALYSIS%b\n\n' "$WHITE" "$RESET"
        printf '  %b[9]%b  URL Security Analyzer\n' "$CYAN" "$RESET"
        printf '  %b[10]%b Website Security Headers\n' "$CYAN" "$RESET"
        printf '  %b[11]%b Cookie Security Checker\n' "$CYAN" "$RESET"
        printf '  %b[12]%b DNS Information\n' "$CYAN" "$RESET"
        printf '  %b[13]%b TLS Certificate Overview\n' "$CYAN" "$RESET"
        printf '\n%bFILE / PASSWORD TOOLS%b\n\n' "$WHITE" "$RESET"
        printf '  %b[14]%b File Hash Analyzer\n' "$CYAN" "$RESET"
        printf '  %b[15]%b File Permission Checker\n' "$CYAN" "$RESET"
        printf '  %b[16]%b Password Strength Checker\n' "$CYAN" "$RESET"
        printf '\n%bASSESSMENT TOOLS%b\n\n' "$WHITE" "$RESET"
        printf '  %b[22]%b Install Assessment Tools\n' "$CYAN" "$RESET"
        printf '  %b[23]%b Nmap Port Scan\n' "$CYAN" "$RESET"
        printf '  %b[24]%b Nikto Web Scanner\n' "$CYAN" "$RESET"
        printf '  %b[25]%b Hydra Credential Tester\n' "$CYAN" "$RESET"
        printf '  %b[26]%b SQLMap Scanner\n' "$CYAN" "$RESET"
        printf '\n%bREPORTS / SYSTEM%b\n\n' "$WHITE" "$RESET"
        printf '  %b[17]%b Generate Security Report\n' "$CYAN" "$RESET"
        printf '  %b[18]%b View Last Report\n' "$CYAN" "$RESET"
        printf '  %b[19]%b List Saved Reports\n' "$CYAN" "$RESET"
        printf '  %b[20]%b Dependency Check\n' "$CYAN" "$RESET"
        printf '  %b[21]%b Environment Check\n' "$CYAN" "$RESET"
        printf '  %b[H]%b  Help\n' "$CYAN" "$RESET"
        printf '  %b[0]%b  Exit\n' "$RED" "$RESET"

        printf '\n'
        read -r -p "CyberShield > " choice

        case "$choice" in
            1) quick_audit ;;
            2) system_information ;;
            3) network_information ;;
            4) connection_monitor ;;
            5) listening_ports ;;
            6) process_overview ;;
            7) local_security_check ;;
            8) log_review ;;
            9) url_analyzer ;;
            10) website_header_scanner ;;
            11) cookie_checker ;;
            12) dns_lookup ;;
            13) tls_certificate_check ;;
            14) file_hash_analyzer ;;
            15) file_permission_checker ;;
            16) password_checker ;;
            17) generate_report ;;
            18) view_last_report ;;
            19) list_reports ;;
            20) show_dependencies ;;
            21) environment_check ;;
            22) install_assessment_tools ;;
            23) run_nmap_scan ;;
            24) run_nikto_scan ;;
            25) run_hydra_scan ;;
            26) run_sqlmap_scan ;;
            h|H) show_help ;;
            0)
                printf '\n%bCyberShield shutting down. Stay secure. 🛡️%b\n' "$GREEN" "$RESET"
                log "CyberShield exited normally"
                exit 0
                ;;
            *)
                error_msg "Unknown option: $choice"
                sleep 1
                ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Entry point
# -----------------------------------------------------------------------------
init
show_banner
main_menu
