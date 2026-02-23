#!/usr/bin/env bash
# Module: tmux — Install TPM + resurrect + continuum for session persistence

module_tmux() {
    is_module_enabled "tmux" || { log_info "Tmux module: skipped (disabled)"; return 0; }
    log_step "Configuring tmux session persistence..."

    # Determine target user's home (we may be running as root via sudo)
    local target_home="${SUDO_USER:+$(eval echo ~"$SUDO_USER")}"
    target_home="${target_home:-$HOME}"
    local target_user="${SUDO_USER:-$(whoami)}"

    # Install tmux if not present
    if ! has_command tmux; then
        require_sudo || return 1
        log_info "Installing tmux..."
        if has_command apt-get; then
            $SUDO apt-get update -qq && $SUDO apt-get install -y -qq tmux
        elif has_command yum; then
            $SUDO yum install -y tmux
        else
            log_error "Cannot install tmux: no supported package manager found"
            return 1
        fi
    fi
    log_info "tmux: $(tmux -V 2>/dev/null || echo 'installed')"

    # Install TPM (Tmux Plugin Manager)
    local tpm_dir="$target_home/.tmux/plugins/tpm"
    if [ ! -d "$tpm_dir" ]; then
        log_info "Installing TPM..."
        git clone https://github.com/tmux-plugins/tpm "$tpm_dir" 2>/dev/null
        # Fix ownership if we're root
        if [ "$(id -u)" -eq 0 ] && [ -n "$SUDO_USER" ]; then
            chown -R "$target_user:$target_user" "$target_home/.tmux"
        fi
    else
        log_info "TPM already installed"
    fi

    # Configure tmux
    local tmux_conf="$target_home/.tmux.conf"
    local save_interval="${TMUX_RESURRECT_SAVE_INTERVAL:-15}"
    local auto_restore="${TMUX_RESURRECT_AUTO_RESTORE:-on}"

    local tmux_block="set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @continuum-restore '$auto_restore'
set -g @continuum-save-interval '$save_interval'
set -g @resurrect-capture-pane-contents 'on'
run '$target_home/.tmux/plugins/tpm/tpm'"

    if ensure_block "$tmux_conf" "agentguard-tmux" "$tmux_block"; then
        log_info "Added tmux plugin config to $tmux_conf"
        # Fix ownership
        if [ "$(id -u)" -eq 0 ] && [ -n "$SUDO_USER" ]; then
            chown "$target_user:$target_user" "$tmux_conf"
        fi
    else
        log_info "Tmux plugin config already present"
    fi

    # Install plugins via TPM
    if [ -x "$tpm_dir/bin/install_plugins" ]; then
        log_info "Installing tmux plugins via TPM..."
        # Run as target user if we're root
        if [ "$(id -u)" -eq 0 ] && [ -n "$SUDO_USER" ]; then
            su - "$target_user" -c "$tpm_dir/bin/install_plugins" 2>/dev/null || true
        else
            "$tpm_dir/bin/install_plugins" 2>/dev/null || true
        fi
    fi

    log_info "Tmux session persistence configured (save every ${save_interval}m, auto-restore: $auto_restore)"
}

module_tmux
