#!/usr/bin/env bash
# Module: health — Install the agentguard-health CLI

module_health() {
    is_module_enabled "health" || { log_info "Health module: skipped (disabled)"; return 0; }
    log_step "Installing agentguard-health..."

    require_sudo || return 1

    local install_path="${TSC_GUARD_INSTALL_PATH:-/usr/local/bin}"
    local base_dir="${AGENTGUARD_BASE:-/tmp/agentguard-payload}"

    $SUDO install -m 755 "$base_dir/remote/agentguard-health" "$install_path/agentguard-health"
    log_info "Installed agentguard-health to $install_path/agentguard-health"
}

module_health
