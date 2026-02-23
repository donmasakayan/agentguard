#!/usr/bin/env bash
# agentguard/runner.sh — Executed on the remote host after tarball extraction
# Sources libraries, loads config, runs modules in order.
# Not intended to be run directly — called by setup.sh.

set -euo pipefail

AGENTGUARD_BASE="$(cd "$(dirname "$0")" && pwd)"
export AGENTGUARD_BASE

# Source libraries
source "$AGENTGUARD_BASE/lib/common.sh"
source "$AGENTGUARD_BASE/lib/config.sh"

# Load config
load_config "$AGENTGUARD_BASE"

echo ""
log_step "========================================="
log_step "  agentguard — VPS hardening for agents  "
log_step "========================================="
echo ""

# Dry run mode
if [ "${DRY_RUN:-false}" = "true" ]; then
    log_warn "DRY RUN MODE — showing what would be executed"
    echo ""
    for module_file in "$AGENTGUARD_BASE"/modules/*.sh; do
        module_name=$(basename "$module_file" .sh | sed 's/^[0-9]*-//')
        if is_module_enabled "$module_name"; then
            log_info "Would run: $module_name"
        else
            log_info "Skipped:   $module_name (disabled)"
        fi
    done
    echo ""
    log_info "Dry run complete. No changes made."
    exit 0
fi

# Run modules in order
for module_file in "$AGENTGUARD_BASE"/modules/*.sh; do
    module_name=$(basename "$module_file" .sh | sed 's/^[0-9]*-//')
    echo ""
    # shellcheck source=/dev/null
    source "$module_file"
done

echo ""
log_step "========================================="
log_step "  agentguard setup complete!             "
log_step "========================================="
log_info "Run 'agentguard-health' to verify."
echo ""
