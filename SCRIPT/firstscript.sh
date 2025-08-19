#!/bin/bash

# First Configuration Script for Arch Linux Installation
# This script runs in chroot environment and performs initial system configuration
# Features: Package installation, locale setup, user creation, bootloader configuration

# Exit on any error, undefined variables, and pipe failures  
set -euo pipefail

# Constants
readonly LOCALE="fr_FR.UTF-8"
readonly KEYMAP="fr-pc"
readonly INTEL_UCODE="intel-ucode"

# Global error tracking
pacman_error_count=0

# Enhanced error tracking for pacman operations
track_pacman_error() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        ((pacman_error_count++))
        echo "Warning: Package installation failed with exit code $exit_code"
    fi
    return $exit_code
}

# Update system packages
update_system() {
    echo "Updating system packages..."
    pacman -Syu --noconfirm || track_pacman_error
}

# Install base system packages
install_base_packages() {
    echo "Installing base system packages..."
    local packages=(
        nano
        base-devel
        openssh
        networkmanager
        wpa_supplicant
        wireless_tools
        netctl
        dialog
        iputils
        man
        git
    )
    
    pacman -S "${packages[@]}" --noconfirm || track_pacman_error
}

# Enable essential services
enable_services() {
    echo "Enabling NetworkManager service..."
    systemctl enable NetworkManager
}

# Setup mkinitcpio editor
setup_mkinitcpio_editor() {
    echo "Installing mkinitcpio editor..."
    if [[ -f /archinstall/SCRIPT/mkinitcpio-editor.sh ]]; then
        mv /archinstall/SCRIPT/mkinitcpio-editor.sh /usr/local/bin/mkinitcpio-editor
        chmod +x /usr/local/bin/mkinitcpio-editor
    else
        echo "Warning: mkinitcpio-editor.sh not found"
    fi
}

# Configure system locale
configure_locale() {
    echo "Configuring system locale..."
    
    # Enable French locale
    sed -i "s/^#\\(${LOCALE}\\s*UTF-8\\)/\\1/" /etc/locale.gen
    locale-gen
    
    echo "LANG=${LOCALE}" > /etc/locale.conf
    echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf
}

# Set root password with retry mechanism
set_root_password() {
    echo "Setting root password:"
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if passwd; then
            echo "Root password set successfully."
            return 0
        else
            echo "Failed to set root password. Attempt $attempt of $max_attempts"
            ((attempt++))
        fi
    done
    
    echo "Error: Failed to set root password after $max_attempts attempts"
    exit 1
}

# Create user account with validation
create_user_account() {
    echo "Creating user account:"
    local username
    local max_attempts=10
    local attempt=1
    
    # Get username with validation
    while [ $attempt -le $max_attempts ]; do
        echo -n "Username: "
        read -r username
        
        # Validate username format
        if [[ ! "$username" =~ ^[a-z][a-z0-9_-]*$ ]]; then
            echo "Error: Username must start with lowercase letter and contain only lowercase letters, numbers, hyphens, and underscores"
            ((attempt++))
            continue
        fi
        
        # Check if username already exists
        if id "$username" &>/dev/null; then
            echo "Error: User '$username' already exists"
            ((attempt++))
            continue
        fi
        
        # Attempt to create user
        if useradd -m -g users -G wheel "$username"; then
            echo "User '$username' created successfully."
            break
        else
            echo "Failed to create user '$username'. Attempt $attempt of $max_attempts"
            ((attempt++))
        fi
    done
    
    if [ $attempt -gt $max_attempts ]; then
        echo "Error: Failed to create user after $max_attempts attempts"
        exit 1
    fi
    
    # Set user password
    echo "Setting password for user '$username':"
    attempt=1
    while [ $attempt -le $max_attempts ]; do
        if passwd "$username"; then
            echo "Password set successfully for user '$username'."
            break
        else
            echo "Failed to set password for user '$username'. Attempt $attempt of $max_attempts"
            ((attempt++))
        fi
    done
    
    if [ $attempt -gt $max_attempts ]; then
        echo "Error: Failed to set user password after $max_attempts attempts"
        exit 1
    fi
}

# Configure sudo access
configure_sudo() {
    echo "Configuring sudo access for wheel group..."
    sed -i 's/^#\s*\(%wheel\s*ALL=(ALL:ALL)\s*ALL\)/\1/' /etc/sudoers
}

# Fix ACPI errors by copying override files
fix_acpi_errors() {
    echo "Configuring ACPI override..."
    mkdir -p /etc/initcpio/acpi_override
    
    if [[ -f /archinstall/CONFIG/ssdt1.aml ]]; then
        cp /archinstall/CONFIG/ssdt1.aml /etc/initcpio/acpi_override/
    else
        echo "Warning: ACPI override file not found"
    fi
}

# Configure mkinitcpio hooks
configure_mkinitcpio_hooks() {
    echo "Configuring mkinitcpio hooks..."
    
    # Find the HOOKS line and replace it
    local hooks_line
    hooks_line=$(grep -v "^#" /etc/mkinitcpio.conf | grep -n 'HOOKS=' | cut -d: -f1)
    
    if [[ -n "$hooks_line" ]]; then
        sed -i "${hooks_line}d" /etc/mkinitcpio.conf
        sed -i "$((hooks_line-1))a HOOKS=(systemd autodetect modconf block keyboard sd-vconsole filesystems fsck acpi_override)" /etc/mkinitcpio.conf
    else
        echo "Warning: Could not find HOOKS line in mkinitcpio.conf"
    fi
}

# Apply system performance tweaks
apply_system_tweaks() {
    echo "Applying system performance tweaks..."
    
    cat > /etc/sysctl.d/99-ramtweaks.conf << 'EOF'
# VM tweaks for better performance
vm.swappiness=2
vm.dirty_bytes=4294967296
vm.dirty_background_bytes=2147483648
vm.vfs_cache_pressure=50
EOF
}

# Configure mkinitcpio compression
configure_mkinitcpio_compression() {
    echo "Configuring mkinitcpio compression..."
    if command -v mkinitcpio-editor >/dev/null 2>&1; then
        mkinitcpio-editor -a xe lz4
    else
        echo "Warning: mkinitcpio-editor not available"
    fi
}

# Install bootloader packages
install_bootloader_packages() {
    echo "Installing bootloader packages..."
    pacman -S efibootmgr "$INTEL_UCODE" --noconfirm || track_pacman_error
}

# Configure systemd-boot
configure_systemd_boot() {
    echo "Configuring systemd-boot bootloader..."
    
    # Get root partition UUID
    local root_uuid
    root_uuid=$(awk '$2 == "/" {print $1}' /etc/fstab)
    
    if [[ -z "$root_uuid" ]]; then
        echo "Error: Could not determine root partition UUID"
        exit 1
    fi
    
    # Install systemd-boot
    bootctl install
    
    # Configure loader
    cat > /boot/loader/loader.conf << 'EOF'
default  arch.conf
timeout  6
console-mode max
editor   no
EOF
    
    # Create boot entries
    create_boot_entries "$root_uuid"
    
    # Update bootloader and enable auto-update service
    bootctl update
    systemctl enable systemd-boot-update.service
}

# Create systemd-boot entries
create_boot_entries() {
    local root_uuid="$1"
    local common_options="root=$root_uuid rw quiet mitigations=auto,nosmt nowatchdog tsc=reliable clocksource=tsc intel_iommu=on iommu=pt vt.global_cursor_default=0 zswap.enabled=1 zswap.shrinker_enabled=1 zswap.compressor=lz4 zswap.max_pool_percent=6 zswap.zpool=zsmalloc"
    
    # Standard Arch Linux entry
    cat > /boot/loader/entries/arch.conf << EOF
title   Arch Linux NVIDIA
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options $common_options modprobe.blacklist=kvmfr
EOF
    
    # GPU Passthrough entry
    cat > /boot/loader/entries/arch-gpupasstrough.conf << EOF
title   Arch Linux GPU PASSTHROUGH
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options $common_options vfio-pci.ids=10de:27a0,10de:22bc
EOF
    
    # Fallback entries
    cat > /boot/loader/entries/fallback-arch.conf << EOF
title   Fallback Arch Linux NVIDIA
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux-fallback.img
options $common_options modprobe.blacklist=kvmfr
EOF
    
    cat > /boot/loader/entries/fallback-arch-gpupasstrough.conf << EOF
title   Fallback Arch Linux GPU PASSTHROUGH
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux-fallback.img
options $common_options vfio-pci.ids=10de:27a0,10de:22bc
EOF
}

# Display installation summary
show_installation_summary() {
    echo
    echo "=== Installation Summary ==="
    if [ "$pacman_error_count" -eq 0 ]; then
        echo "✓ All package installations completed successfully."
    else
        echo "⚠ There were $pacman_error_count package installation errors."
        echo "  Please review the output above for details."
    fi
    echo "==========================="
    echo
}

# Main configuration process
main() {
    echo "Starting first configuration script..."
    
    update_system
    install_base_packages
    enable_services
    setup_mkinitcpio_editor
    configure_locale
    set_root_password
    create_user_account
    configure_sudo
    fix_acpi_errors
    configure_mkinitcpio_hooks
    apply_system_tweaks
    configure_mkinitcpio_compression
    install_bootloader_packages
    configure_systemd_boot
    show_installation_summary
    
    echo "First configuration script completed. Press any key to continue..."
    read -r
}

# Execute main function
main "$@"
