#!/usr/bin/env bash
# agentguard/lib/common.sh — Shared utilities for all modules
# Sourced by runner.sh; do not execute directly.

# Colors (disabled if not a terminal)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' BOLD='' NC=''
fi

log_info()  { echo -e "${GREEN}[agentguard]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[agentguard]${NC} $*" >&2; }
log_error() { echo -e "${RED}[agentguard]${NC} $*" >&2; }
log_step()  { echo -e "${BLUE}[agentguard]${NC} ${BOLD}$*${NC}"; }

# Idempotent: ensure a line exists in a file (appends if missing)
ensure_line() {
    local file="$1"
    local line="$2"
    if ! grep -qF "$line" "$file" 2>/dev/null; then
        echo "$line" >> "$file"
        return 0  # added
    fi
    return 1  # already present
}

# Idempotent: ensure a block of text (delimited by markers) exists in a file
ensure_block() {
    local file="$1"
    local marker="$2"
    local content="$3"
    if grep -qF "$marker" "$file" 2>/dev/null; then
        return 1  # already present
    fi
    {
        echo ""
        echo "# $marker"
        echo "$content"
        echo "# end $marker"
    } >> "$file"
    return 0
}

# Backup a file before first modification (idempotent)
backup_file() {
    local file="$1"
    local backup="${file}.agentguard-backup"
    if [ -f "$file" ] && [ ! -f "$backup" ]; then
        cp "$file" "$backup"
        log_info "Backed up $file -> $backup"
    fi
}

# Check if running as root or can sudo
require_sudo() {
    if [ "$(id -u)" -eq 0 ]; then
        SUDO=""
    elif command -v sudo &>/dev/null; then
        SUDO="sudo"
    else
        log_error "This module requires root or sudo access"
        return 1
    fi
}

# Check if a command exists
has_command() {
    command -v "$1" &>/dev/null
}
