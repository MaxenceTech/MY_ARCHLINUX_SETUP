#!/bin/bash

# Arch Linux Installation Script
# This script performs automated Arch Linux installation with NVMe disk support
# Features: WiFi setup, disk partitioning, package installation, and system configuration

# Exit on any error, undefined variables, and pipe failures
set -euo pipefail

# Constants
readonly KEYMAP="fr-pc"
readonly PING_TARGET="google.com"
readonly PING_COUNT=5
readonly MAX_RETRIES=10
readonly SLEEP_DURATION=10

# Cleanup any existing mounts (ignore errors if not mounted)
cleanup_mounts() {
    echo "Cleaning up existing mounts..."
    umount /dev/nvme0n1p1 2>/dev/null || true
    umount /dev/nvme0n1p2 2>/dev/null || true
    swapoff /dev/nvme0n1p3 2>/dev/null || true
}

# Set keyboard layout
setup_keyboard() {
    echo "Setting keyboard layout to $KEYMAP..."
    loadkeys "$KEYMAP"
}

# Test internet connectivity
test_connectivity() {
    ping -c "$PING_COUNT" "$PING_TARGET" >/dev/null 2>&1
}

# Setup WiFi connection
setup_wifi() {
    local retry_count=$MAX_RETRIES
    
    if test_connectivity; then
        echo "Internet connection already available."
        return 0
    fi
    
    while [ $retry_count -gt 0 ]; do
        echo "Scanning for available networks..."
        iwctl station wlan0 scan
        iwctl station wlan0 get-networks
        
        echo -e "\n\nPlease enter WiFi credentials:"
        echo -n "SSID: "
        read -r ssid
        
        if [[ -z "$ssid" ]]; then
            echo "Error: SSID cannot be empty"
            ((retry_count--))
            continue
        fi
        
        echo -n "Password: "
        read -rs password
        echo
        
        if [[ -z "$password" ]]; then
            echo "Error: Password cannot be empty"
            ((retry_count--))
            continue
        fi
        
        echo "Attempting to connect to network '$ssid'..."
        if iwctl station wlan0 connect "$ssid" --passphrase="$password"; then
            echo "WiFi connection initiated. Testing connectivity..."
            sleep "$SLEEP_DURATION"
            
            if test_connectivity; then
                echo "Successfully connected to internet!"
                return 0
            else
                echo "Connected to WiFi but no internet access."
            fi
        else
            echo "Failed to connect to WiFi network."
        fi
        
        ((retry_count--))
        if [ $retry_count -gt 0 ]; then
            echo "Retries remaining: $retry_count"
        fi
    done
    
    echo "Error: Failed to establish internet connection after all retries."
    exit 1
}

# Detect and configure NVMe disks
setup_nvme_disks() {
    local nvme_disks
    mapfile -t nvme_disks < <(ls /dev/nvme*n1 2>/dev/null || true)
    local nvme_count=${#nvme_disks[@]}
    
    echo "Detected $nvme_count NVMe disk(s)."
    
    if [ "$nvme_count" -eq 0 ]; then
        echo "Error: No NVMe disks found on this system."
        exit 1
    elif [ "$nvme_count" -eq 1 ]; then
        setup_single_nvme_disk "${nvme_disks[0]}"
    elif [ "$nvme_count" -eq 2 ]; then
        setup_dual_nvme_disks "${nvme_disks[@]}"
    else
        echo "Error: This script only handles up to 2 NVMe disks. Found $nvme_count disks:"
        printf '  %s\n' "${nvme_disks[@]}"
        exit 1
    fi
}

# Configure single NVMe disk setup
setup_single_nvme_disk() {
    local disk="$1"
    echo "Configuring single NVMe disk: $disk"
    
    # Partition disk: 2GB EFI, 8GB swap, rest for root
    echo "Creating partitions..."
    sgdisk -Z "$disk"
    sgdisk -n 1:0:+2G -t 1:ef00 "$disk"      # EFI system partition
    sgdisk -n 2:0:+8G -t 2:8200 "$disk"     # Swap partition
    sgdisk -n 3:0:0 -t 3:8300 "$disk"       # Linux filesystem
    
    # Format partitions
    echo "Formatting partitions..."
    mkfs.fat -F32 "${disk}p1"
    mkswap --label diskswap "${disk}p2"
    mkfs.ext4 "${disk}p3"
    
    # Mount partitions
    echo "Mounting partitions..."
    mount "${disk}p3" /mnt
    mount --mkdir "${disk}p1" /mnt/boot
    swapon "${disk}p2"
}

# Configure dual NVMe disk setup
setup_dual_nvme_disks() {
    local -a nvme_disks=("$@")
    local disk1 disk2
    
    echo "Two NVMe disks detected:"
    for i in "${!nvme_disks[@]}"; do
        echo "$((i+1)). ${nvme_disks[i]}"
    done
    
    # Get user choice for primary disk
    while true; do
        echo -n "Which disk do you want as the primary disk? (1 or 2): "
        read -r choice
        case $choice in
            1)
                disk1="${nvme_disks[0]}"
                disk2="${nvme_disks[1]}"
                break
                ;;
            2)
                disk1="${nvme_disks[1]}"
                disk2="${nvme_disks[0]}"
                break
                ;;
            *)
                echo "Error: Invalid choice. Please enter 1 or 2."
                ;;
        esac
    done
    
    echo "Primary disk (system): $disk1"
    echo "Secondary disk (data): $disk2"
    
    # Configure primary disk (EFI + root)
    echo "Configuring primary disk..."
    sgdisk -Z "$disk1"
    sgdisk -n 1:0:+2G -t 1:ef00 "$disk1"    # EFI system partition
    sgdisk -n 2:0:0 -t 2:8300 "$disk1"      # Linux filesystem
    mkfs.fat -F32 "${disk1}p1"
    mkfs.ext4 "${disk1}p2"
    
    # Configure secondary disk (swap + data)
    echo "Configuring secondary disk..."
    sgdisk -Z "$disk2"
    sgdisk -n 1:0:+8G -t 1:8200 "$disk2"    # Swap partition
    sgdisk -n 2:0:0 -t 2:8300 "$disk2"      # Data partition
    mkswap --label diskswap "${disk2}p1"
    mkfs.ext4 "${disk2}p2"
    
    # Mount all partitions
    echo "Mounting partitions..."
    mount "${disk1}p2" /mnt
    mount --mkdir "${disk1}p1" /mnt/boot
    mount --mkdir "${disk2}p2" /mnt/data
    swapon "${disk2}p1"
}

# Install base system
install_base_system() {
    echo "Copying pacman configuration..."
    if ! tee /etc/pacman.conf < CONFIG/pacman.conf; then
        echo "Error: Failed to copy pacman configuration"
        exit 1
    fi
    
    echo "Installing base system packages..."
    if ! pacstrap /mnt base linux linux-headers linux-firmware; then
        echo "Error: Failed to install base system"
        exit 1
    fi
    
    echo "Base system installation completed successfully."
}

# Generate filesystem table
generate_fstab() {
    echo "Generating filesystem table..."
    if ! genfstab -U /mnt | tee -a /mnt/etc/fstab; then
        echo "Error: Failed to generate fstab"
        exit 1
    fi
}

# Copy installation files
copy_install_files() {
    echo "Copying installation files to new system..."
    mkdir -p /mnt/archinstall
    
    if ! cp -r ./* /mnt/archinstall; then
        echo "Error: Failed to copy installation files"
        exit 1
    fi
    
    chmod -R 755 /mnt/archinstall/SCRIPT/*
    
    # Copy pacman configuration to new system
    if ! tee /mnt/etc/pacman.conf < CONFIG/pacman.conf; then
        echo "Error: Failed to copy pacman configuration to new system"
        exit 1
    fi
}

# Execute chroot script
execute_chroot_script() {
    echo "Executing first configuration script in chroot environment..."
    if ! arch-chroot /mnt bash /archinstall/SCRIPT/firstscript.sh; then
        echo "Error: Chroot script execution failed"
        exit 1
    fi
}

# Cleanup and reboot
cleanup_and_reboot() {
    echo "Unmounting filesystems..."
    umount -a || true
    
    echo "Installation completed! Rebooting in 5 seconds..."
    sleep 5
    reboot
}

# Main installation process
main() {
    echo "Starting Arch Linux installation..."
    
    cleanup_mounts
    setup_keyboard
    setup_wifi
    setup_nvme_disks
    install_base_system
    generate_fstab
    copy_install_files
    execute_chroot_script
    cleanup_and_reboot
}

# Execute main function
main "$@"
