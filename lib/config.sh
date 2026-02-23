#!/usr/bin/env bash
# agentguard/lib/config.sh — Config loader and module enablement check
# Sourced by runner.sh; do not execute directly.

# Load config: defaults first, then user overrides
load_config() {
    local base_dir="$1"

    # Load defaults
    if [ -f "$base_dir/agentguard.defaults.conf" ]; then
        # shellcheck source=/dev/null
        source "$base_dir/agentguard.defaults.conf"
    fi

    # Load user overrides (uploaded alongside defaults)
    if [ -f "$base_dir/agentguard.user.conf" ]; then
        # shellcheck source=/dev/null
        source "$base_dir/agentguard.user.conf"
        log_info "Loaded user config overrides"
    fi
}

# Check if a module is enabled in config
# Usage: is_module_enabled "swap" && run_module
is_module_enabled() {
    local module="$1"
    local var="MODULE_${module^^}"  # e.g., MODULE_SWAP
    local value="${!var:-}"

    # If MODULES_FILTER is set (from --module flag), only run those
    if [ -n "${MODULES_FILTER:-}" ]; then
        if echo ",$MODULES_FILTER," | grep -q ",$module,"; then
            return 0
        fi
        return 1
    fi

    # Default: check config variable (default enabled)
    [ "${value:-true}" = "true" ]
}
