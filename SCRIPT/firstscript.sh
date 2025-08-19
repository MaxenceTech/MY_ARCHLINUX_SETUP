#!/bin/bash

#==============================================================================
# First Configuration Script (Chroot Environment)
#==============================================================================
# Description: Initial system configuration executed in chroot environment
#              Configures locale, users, bootloader, and basic system settings
# Author: MaxenceTech
# Usage: Executed automatically by install.sh via arch-chroot
# Environment: Runs inside chroot (/mnt from installation script)
#==============================================================================

# Exit on any error, undefined variables, and pipe failures  
set -euo pipefail

#==============================================================================
# PACKAGE INSTALLATION TRACKING
#==============================================================================

# Initialize error tracking for package installations
pacmanerror=0

#==============================================================================
# SYSTEM UPDATE AND BASE PACKAGES
#==============================================================================

# Update package database and system
echo "Updating system packages..."
pacman -Syu --noconfirm
pacmanerror=$((pacmanerror + $?))

# Install essential system packages
echo "Installing base development and networking packages..."
pacman -S nano base-devel openssh networkmanager wpa_supplicant wireless_tools \
    netctl dialog iputils man git --noconfirm
pacmanerror=$((pacmanerror + $?))

#==============================================================================
# NETWORK CONFIGURATION
#==============================================================================

# Enable NetworkManager for network management
systemctl enable NetworkManager

#==============================================================================
# SYSTEM UTILITIES SETUP
#==============================================================================

# Install custom mkinitcpio editor utility
mv /archinstall/SCRIPT/mkinitcpio-editor.sh /usr/local/bin/mkinitcpio-editor

#==============================================================================
# LOCALE AND KEYBOARD CONFIGURATION
#==============================================================================

# Configure French locale
echo "Configuring system locale..."
sed -i 's/^#\(fr_FR.UTF-8\s*UTF-8\)/\1/' /etc/locale.gen
locale-gen
echo "LANG=fr_FR.UTF-8" > /etc/locale.conf
echo "KEYMAP=fr-pc" > /etc/vconsole.conf

#==============================================================================
# USER ACCOUNT CONFIGURATION
#==============================================================================

# Configure root password with retry loop
echo "Mot de passe root :"
x=10
while [ $x != 0 ]
do
    passwd
    x=$?
done

# Create user account with validation
echo "Nom d'utisateur :"
x=10
while [ $x != 0 ]
do
    read -r nomutilisateur
    # Basic username validation (alphanumeric, underscore, hyphen only)
    if [[ "$nomutilisateur" =~ ^[a-zA-Z0-9_-]+$ ]] && [ ${#nomutilisateur} -ge 3 ] && [ ${#nomutilisateur} -le 32 ]; then
        useradd -m -g users -G wheel "$nomutilisateur"
        x=$?
    else
        echo "Invalid username. Use 3-32 characters (letters, numbers, underscore, hyphen only)."
        x=1
    fi
done

# Set user password with retry loop
echo "Mot de passe utiliateur :"
x=10
while [ $x != 0 ]
do
    passwd "$nomutilisateur"
    x=$?
done

# Enable sudo access for wheel group
sed -i 's/^#\s*\(%wheel\s*ALL=(ALL:ALL)\s*ALL\)/\1/' /etc/sudoers

#==============================================================================
# ACPI CONFIGURATION
#==============================================================================

# Fix ACPI error with custom SSDT
echo "Configuring ACPI override..."
mkdir -p /etc/initcpio/acpi_override
cp /archinstall/CONFIG/ssdt1.aml /etc/initcpio/acpi_override

#==============================================================================
# KERNEL CONFIGURATION
#==============================================================================

# Update mkinitcpio hooks for ACPI support
echo "Updating mkinitcpio configuration..."
hooksvar=$(grep -v  -n "^#" /etc/mkinitcpio.conf | grep 'HOOKS=')
ligne="${hooksvar%:*}"
sed -i "$((ligne)) d" /etc/mkinitcpio.conf
sed -i "$((ligne-1)) a HOOKS=(systemd autodetect modconf block keyboard sd-vconsole filesystems fsck acpi_override)" /etc/mkinitcpio.conf

#==============================================================================
# SYSTEM PERFORMANCE TWEAKS
#==============================================================================

# Configure system performance parameters
echo "Applying system performance tweaks..."
echo "vm.swappiness=2
vm.dirty_bytes = 4294967296
vm.dirty_background_bytes = 2147483648
vm.vfs_cache_pressure=50" | tee /etc/sysctl.d/99-ramtweaks.conf

#==============================================================================
# BOOTLOADER CONFIGURATION
#==============================================================================

# Configure custom kernel modules and microcode
echo "Configuring bootloader..."
mkinitcpio-editor -a xe lz4
pacman -S efibootmgr intel-ucode --noconfirm
pacmanerror=$((pacmanerror + $?))

# Get root partition UUID for bootloader configuration
PARTUUIDGREP=$(awk '$2 == "/" {print $1}' /etc/fstab)

# Install and configure systemd-boot
bootctl install

# Create bootloader configuration
echo "default  arch.conf
timeout  6
console-mode max
editor   no" | tee /boot/loader/loader.conf

# Create boot entries for different configurations
echo "title   Arch Linux NVIDIA
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options root=$PARTUUIDGREP rw quiet mitigations=auto,nosmt nowatchdog tsc=reliable clocksource=tsc intel_iommu=on iommu=pt vt.global_cursor_default=0 zswap.enabled=1 zswap.shrinker_enabled=1 zswap.compressor=lz4 zswap.max_pool_percent=6 zswap.zpool=zsmalloc modprobe.blacklist=kvmfr" | tee /boot/loader/entries/arch.conf

echo "title   Arch Linux GPU PASSTROUGH
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options root=$PARTUUIDGREP rw quiet mitigations=auto,nosmt nowatchdog tsc=reliable clocksource=tsc intel_iommu=on iommu=pt vfio-pci.ids=10de:27a0,10de:22bc vt.global_cursor_default=0 zswap.enabled=1 zswap.shrinker_enabled=1 zswap.compressor=lz4 zswap.max_pool_percent=6 zswap.zpool=zsmalloc" | tee /boot/loader/entries/arch-gpupasstrough.conf

echo "title   Fallback Arch Linux NVIDIA
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux-fallback.img
options root=$PARTUUIDGREP rw quiet mitigations=auto,nosmt nowatchdog tsc=reliable clocksource=tsc intel_iommu=on iommu=pt vt.global_cursor_default=0 zswap.enabled=1 zswap.shrinker_enabled=1 zswap.compressor=lz4 zswap.max_pool_percent=6 zswap.zpool=zsmalloc modprobe.blacklist=kvmfr" | tee /boot/loader/entries/fallback-arch.conf

echo "title   Fallback Arch Linux GPU PASSTROUGH
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux-fallback.img
options root=$PARTUUIDGREP rw quiet mitigations=auto,nosmt nowatchdog tsc=reliable clocksource=tsc intel_iommu=on iommu=pt vfio-pci.ids=10de:27a0,10de:22bc vt.global_cursor_default=0 zswap.enabled=1 zswap.shrinker_enabled=1 zswap.compressor=lz4 zswap.max_pool_percent=6 zswap.zpool=zsmalloc" | tee /boot/loader/entries/fallback-arch-gpupasstrough.conf

# Update bootloader and enable automatic updates
bootctl update
systemctl enable systemd-boot-update.service

#==============================================================================
# INSTALLATION SUMMARY
#==============================================================================

# Report installation status
if [ "$pacmanerror" -eq 0 ]; then
    echo "Every pacman installation occurred without error."
else
    echo "There was an error in one or more pacman installations."
fi

echo "First configuration script completed. Press any key to continue..."
read -r -p "Press any key to continue..."
