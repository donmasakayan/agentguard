#!/usr/bin/env bash
# Module: preflight — OS detection, sudo check, disk space validation
# Always runs regardless of module filter.

module_preflight() {
    log_step "Running preflight checks..."

    # OS detection
    if [ -f /etc/os-release ]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        log_info "OS: $PRETTY_NAME"
    else
        log_warn "Could not detect OS (no /etc/os-release)"
    fi

    # Sudo check
    require_sudo || return 1

    # Disk space check (warn if less than 10GB free on /)
    local free_kb
    free_kb=$(df / --output=avail 2>/dev/null | tail -1 | tr -d ' ' || df -k / | tail -1 | awk '{print $4}')
    local free_gb=$((free_kb / 1024 / 1024))
    if [ "$free_gb" -lt 10 ]; then
        log_warn "Low disk space: ${free_gb}GB free on /"
    else
        log_info "Disk space: ${free_gb}GB free on /"
    fi

    # Memory info
    local total_mem_kb
    total_mem_kb=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
    local total_mem_gb=$((total_mem_kb / 1024 / 1024))
    log_info "RAM: ${total_mem_gb}GB total"

    # Check existing swap
    local swap_total
    swap_total=$(grep SwapTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
    local swap_gb=$((swap_total / 1024 / 1024))
    log_info "Swap: ${swap_gb}GB configured"
}

module_preflight
