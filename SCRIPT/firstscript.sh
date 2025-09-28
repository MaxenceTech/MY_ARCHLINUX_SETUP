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
pacman -S sbctl nano base-devel openssh networkmanager wpa_supplicant wireless_tools \
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
chmod +x /usr/local/bin/mkinitcpio-editor

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

set +euo pipefail

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

set -euo pipefail

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
sed -i "$((ligne-1)) a HOOKS=(systemd autodetect microcode modconf keyboard sd-vconsole block sd-encrypt filesystems fsck acpi_override)" /etc/mkinitcpio.conf

#==============================================================================
# SYSTEM PERFORMANCE TWEAKS
#==============================================================================

# Configure system performance parameters
echo "Applying system performance tweaks..."
echo "vm.swappiness=10
vm.dirty_bytes = 4294967296
vm.dirty_background_bytes = 2147483648
vm.vfs_cache_pressure=50" | tee /etc/sysctl.d/99-ramtweaks.conf

# Blacklist Watchdogs module
echo "blacklist iTCO_wdt" | tee /etc/modprobe.d/blacklist_intelwatchdog.conf

#==============================================================================
# BOOTLOADER CONFIGURATION
#==============================================================================

# Configure custom kernel modules and microcode
echo "Configuring bootloader..."
mkinitcpio-editor -a xe lz4
pacman -S efibootmgr intel-ucode --noconfirm
pacmanerror=$((pacmanerror + $?))

# Get root partition UUID for bootloader configuration
luks_dev=$(LC_ALL=C cryptsetup status root | awk -F': ' '/device:/ {print $2}')
# Trim leading
luks_dev="${luks_dev#"${luks_dev%%[![:space:]]*}"}"
# Trim trailing
luks_dev="${luks_dev%"${luks_dev##*[![:space:]]}"}"

PARTUUIDGREP=$(cryptsetup luksUUID -- "$luks_dev")

# Create boot entries for different configurations

echo "rd.luks.name=$PARTUUIDGREP=root root=/dev/mapper/root rw quiet mitigations=auto,nosmt nowatchdog tsc=reliable clocksource=tsc intel_iommu=on iommu=pt vt.global_cursor_default=0 zswap.enabled=1 zswap.shrinker_enabled=1 zswap.compressor=lz4 zswap.max_pool_percent=12 zswap.zpool=zsmalloc modprobe.blacklist=kvmfr video=HDMI-A-1:d video=DP-1:d video=DP-2:d" | tee /etc/kernel/arch_cmdline
echo "rd.luks.name=$PARTUUIDGREP=root root=/dev/mapper/root rw quiet mitigations=auto,nosmt nowatchdog tsc=reliable clocksource=tsc intel_iommu=on iommu=pt vfio-pci.ids=10de:27a0,10de:22bc vt.global_cursor_default=0 zswap.enabled=1 zswap.shrinker_enabled=1 zswap.compressor=lz4 zswap.max_pool_percent=12 zswap.zpool=zsmalloc" | tee /etc/kernel/arch_gpupasstrough_cmdline

echo 'ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux"

PRESETS=('nvidia' 'nvidia_fallback' 'gpupasstrough' 'gpupasstrough_fallback')

#default_config="/etc/mkinitcpio.conf"
#default_image="/boot/initramfs-linux.img"
nvidia_uki="/efi/EFI/Linux/nvidia-linux.efi"
nvidia_options="--cmdline /etc/kernel/arch_cmdline"

#fallback_config="/etc/mkinitcpio.conf"
#fallback_image="/boot/initramfs-linux-fallback.img"
nvidia_fallback_uki="/efi/EFI/Linux/nvidia_fallback-linux.efi"
nvidia_fallback_options="--cmdline /etc/kernel/arch_cmdline"


#default_config="/etc/mkinitcpio.conf"
#default_image="/boot/initramfs-linux.img"
gpupasstrough_uki="/efi/EFI/Linux/gpupasstrough-linux.efi"
gpupasstrough_options="--cmdline /etc/kernel/arch_gpupasstrough_cmdline"

#fallback_config="/etc/mkinitcpio.conf"
#fallback_image="/boot/initramfs-linux-fallback.img"
gpupasstrough_fallback_uki="/efi/EFI/Linux/gpupasstrough_fallback-linux.efi"
gpupasstrough_fallback_options="--cmdline /etc/kernel/arch_gpupasstrough_cmdline"' | tee /etc/mkinitcpio.d/linux.preset

rm /boot/initramfs-linux.img
rm /boot/initramfs-linux-fallback.img

# Install and configure systemd-boot
bootctl install

read -r -p "Bootloader installed. Press any key to continue..."

# Create bootloader configuration
echo "default  @saved
timeout  6
console-mode max
editor   no" | tee /efi/loader/loader.conf

mkinitcpio -p linux

# Update bootloader and enable automatic updates
bootctl update || [[ $? -eq 1 ]]

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
