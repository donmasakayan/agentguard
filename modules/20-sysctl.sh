#!/usr/bin/env bash
# Module: sysctl — Kernel tuning + OOM protection for critical services

module_sysctl() {
    is_module_enabled "sysctl" || { log_info "Sysctl module: skipped (disabled)"; return 0; }
    log_step "Configuring sysctl and OOM protection..."

    require_sudo || return 1

    local swappiness="${SWAPPINESS:-60}"

    # Set vm.swappiness
    local current_swappiness
    current_swappiness=$(cat /proc/sys/vm/swappiness 2>/dev/null || echo "unknown")
    if [ "$current_swappiness" != "$swappiness" ]; then
        $SUDO sysctl -w vm.swappiness="$swappiness" >/dev/null
        log_info "Set vm.swappiness=$swappiness (was $current_swappiness)"
    else
        log_info "vm.swappiness already $swappiness"
    fi

    # Persist in sysctl.conf
    local sysctl_file="/etc/sysctl.d/99-agentguard.conf"
    cat <<EOF | $SUDO tee "$sysctl_file" >/dev/null
# agentguard: VPS tuning for multi-agent workflows
vm.swappiness=$swappiness
EOF
    $SUDO sysctl --system >/dev/null 2>&1

    # OOM protection for critical services
    local services="${OOM_PROTECT_SERVICES:-sshd dbus systemd-journald}"
    for service in $services; do
        local override_dir="/etc/systemd/system/${service}.service.d"
        local override_file="$override_dir/agentguard-oom.conf"

        if [ -f "$override_file" ]; then
            log_info "OOM protection already set for $service"
            continue
        fi

        $SUDO mkdir -p "$override_dir"
        cat <<EOF | $SUDO tee "$override_file" >/dev/null
[Service]
OOMScoreAdjust=-900
EOF
        log_info "Set OOM protection for $service (OOMScoreAdjust=-900)"
    done

    $SUDO systemctl daemon-reload 2>/dev/null || true

    log_info "Sysctl and OOM protection configured"
}

module_sysctl
