#!/usr/bin/env bash
# Module: swap — Create swap file with fstab entry

module_swap() {
    is_module_enabled "swap" || { log_info "Swap module: skipped (disabled)"; return 0; }
    log_step "Configuring swap (${SWAP_SIZE_GB}GB)..."

    require_sudo || return 1

    local swap_file="${SWAP_FILE:-/swapfile}"
    local swap_size="${SWAP_SIZE_GB:-8}"

    # Check if swap file already exists and is active
    if swapon --show 2>/dev/null | grep -q "$swap_file"; then
        log_info "Swap already active at $swap_file — skipping"
        return 0
    fi

    # Create swap file if it doesn't exist
    if [ ! -f "$swap_file" ]; then
        log_info "Creating ${swap_size}GB swap file at $swap_file..."
        $SUDO dd if=/dev/zero of="$swap_file" bs=1G count="$swap_size" status=progress 2>&1
        $SUDO chmod 600 "$swap_file"
        $SUDO mkswap "$swap_file"
        log_info "Swap file created"
    else
        log_info "Swap file already exists at $swap_file"
        $SUDO chmod 600 "$swap_file"
    fi

    # Enable swap
    $SUDO swapon "$swap_file" 2>/dev/null || true

    # Add to fstab if not present
    if ! grep -q "$swap_file" /etc/fstab 2>/dev/null; then
        backup_file /etc/fstab
        echo "$swap_file none swap sw 0 0" | $SUDO tee -a /etc/fstab >/dev/null
        log_info "Added swap to /etc/fstab"
    else
        log_info "Swap already in /etc/fstab"
    fi

    log_info "Swap configured: $(swapon --show 2>/dev/null || echo 'active')"
}

module_swap
