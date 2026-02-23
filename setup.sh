#!/usr/bin/env bash
# agentguard/setup.sh — Local entry point
# Bundles modules + config into a tarball, uploads to VPS, executes remotely.
#
# Usage:
#   ./setup.sh user@host [--config ./myconfig.conf] [--module swap,tmux] [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Defaults
SSH_TARGET=""
CONFIG_FILE=""
MODULES_FILTER=""
DRY_RUN=false
SSH_OPTS="-o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new"

# Parse args
while [ $# -gt 0 ]; do
    case "$1" in
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --module|--modules)
            MODULES_FILTER="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            echo "Usage: ./setup.sh user@host [options]"
            echo ""
            echo "Options:"
            echo "  --config FILE    User config file (overrides defaults)"
            echo "  --module LIST    Comma-separated modules to run (e.g., swap,tmux)"
            echo "  --dry-run        Show what would be done without making changes"
            echo "  --help           Show this help"
            echo ""
            echo "Modules: swap, sysctl, tmux, tsc_guard, health"
            echo ""
            echo "Examples:"
            echo "  ./setup.sh ubuntu@my-vps"
            echo "  ./setup.sh ubuntu@my-vps --module tsc_guard,health"
            echo "  ./setup.sh ubuntu@my-vps --config ./myconfig.conf --dry-run"
            exit 0
            ;;
        -*)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
        *)
            if [ -z "$SSH_TARGET" ]; then
                SSH_TARGET="$1"
            else
                echo "Unexpected argument: $1" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

if [ -z "$SSH_TARGET" ]; then
    echo "Error: SSH target required (e.g., user@host)" >&2
    echo "Run './setup.sh --help' for usage." >&2
    exit 1
fi

echo "agentguard: Preparing payload..."

# Create temp dir for payload
PAYLOAD_DIR=$(mktemp -d)
trap 'rm -rf "$PAYLOAD_DIR"' EXIT

# Copy files into payload
mkdir -p "$PAYLOAD_DIR/agentguard-payload"
cp -r "$SCRIPT_DIR/lib" "$PAYLOAD_DIR/agentguard-payload/"
cp -r "$SCRIPT_DIR/modules" "$PAYLOAD_DIR/agentguard-payload/"
cp -r "$SCRIPT_DIR/remote" "$PAYLOAD_DIR/agentguard-payload/"
cp "$SCRIPT_DIR/runner.sh" "$PAYLOAD_DIR/agentguard-payload/"
cp "$SCRIPT_DIR/agentguard.defaults.conf" "$PAYLOAD_DIR/agentguard-payload/"

# Copy user config if provided
if [ -n "$CONFIG_FILE" ]; then
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: Config file not found: $CONFIG_FILE" >&2
        exit 1
    fi
    cp "$CONFIG_FILE" "$PAYLOAD_DIR/agentguard-payload/agentguard.user.conf"
    echo "agentguard: Using config: $CONFIG_FILE"
fi

# Create tarball (COPYFILE_DISABLE prevents macOS xattr headers)
TARBALL="$PAYLOAD_DIR/agentguard-payload.tar.gz"
COPYFILE_DISABLE=1 tar czf "$TARBALL" -C "$PAYLOAD_DIR" agentguard-payload

TARBALL_SIZE=$(wc -c < "$TARBALL" | tr -d ' ')
echo "agentguard: Payload size: ${TARBALL_SIZE} bytes"

# Upload
echo "agentguard: Uploading to $SSH_TARGET..."
# shellcheck disable=SC2086
ssh $SSH_OPTS "$SSH_TARGET" 'rm -rf /tmp/agentguard-payload && mkdir -p /tmp' </dev/null
# shellcheck disable=SC2086
cat "$TARBALL" | ssh $SSH_OPTS "$SSH_TARGET" 'cat > /tmp/agentguard-payload.tar.gz'

# Extract and execute
echo "agentguard: Executing on $SSH_TARGET..."
REMOTE_ENV="DRY_RUN=$DRY_RUN"
if [ -n "$MODULES_FILTER" ]; then
    REMOTE_ENV="$REMOTE_ENV MODULES_FILTER=$MODULES_FILTER"
fi

# shellcheck disable=SC2086,SC2029
ssh $SSH_OPTS "$SSH_TARGET" "
    cd /tmp && \
    tar xzf agentguard-payload.tar.gz 2>/dev/null && \
    sudo $REMOTE_ENV bash agentguard-payload/runner.sh && \
    rm -rf /tmp/agentguard-payload /tmp/agentguard-payload.tar.gz
"

echo ""
echo "agentguard: Done! SSH in and run 'agentguard-health' to verify."
