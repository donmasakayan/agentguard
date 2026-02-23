#!/usr/bin/env bash
# Module: tsc-guard — Install semaphore wrapper for TypeScript compiler

module_tsc_guard() {
    is_module_enabled "tsc_guard" || { log_info "tsc-guard module: skipped (disabled)"; return 0; }
    log_step "Installing tsc-guard (max ${TSC_GUARD_MAX_SLOTS:-3} concurrent tsc)..."

    require_sudo || return 1

    local install_path="${TSC_GUARD_INSTALL_PATH:-/usr/local/bin}"
    local base_dir="${AGENTGUARD_BASE:-/tmp/agentguard-payload}"

    # Install tsc-guard binary
    $SUDO install -m 755 "$base_dir/remote/tsc-guard" "$install_path/tsc-guard"
    log_info "Installed tsc-guard to $install_path/tsc-guard"

    # Install tsc-guard-install helper
    $SUDO install -m 755 "$base_dir/remote/tsc-guard-install" "$install_path/tsc-guard-install"
    log_info "Installed tsc-guard-install to $install_path/tsc-guard-install"

    # Create semaphore directory
    mkdir -p /tmp/tsc-semaphore
    chmod 1777 /tmp/tsc-semaphore

    # Auto-install into project directories if configured
    local project_dirs="${TSC_GUARD_PROJECT_DIRS:-}"
    if [ -n "$project_dirs" ]; then
        for dir in $project_dirs; do
            if [ -d "$dir/node_modules/.bin" ]; then
                "$install_path/tsc-guard-install" "$dir"
            else
                log_warn "Skipping $dir (no node_modules/.bin found)"
            fi
        done
    fi

    log_info "tsc-guard installed. Run 'tsc-guard-install <project-dir>' to activate per-project."
}

module_tsc_guard
