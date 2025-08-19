#!/bin/bash

#==============================================================================
# Arch Linux Installation Script
#==============================================================================
# Description: Main installation script for setting up Arch Linux with 
#              automated partitioning, package installation, and chroot setup
# Author: MaxenceTech
# Usage: Run this script from Arch Linux live environment
# Prerequisites: Active internet connection, booted from Arch Linux ISO
#==============================================================================

# Exit on any error, undefined variables, and pipe failures
set -euo pipefail

#==============================================================================
# CLEANUP AND PREPARATION
#==============================================================================

# Cleanup any existing mounts (ignore errors if not mounted)

for mount in $(mount | grep '/dev/nvme' | cut -d' ' -f1); do
  echo "Unmounting $mount"
  sudo umount $mount 2>/dev/null || true
done

for swap in $(cat /proc/swaps | grep '/dev/nvme' | cut -d' ' -f1); do
  echo "Disabling swap on $swap"
  sudo swapoff $swap 2>/dev/null || true
done

for disk in /dev/nvme*n1; do
  echo "Sanitizing $disk..."
  nvme sanitize "$disk" -a 0x02
done

sleep 60

# Set French keyboard layout
loadkeys fr-pc

#==============================================================================
# NETWORK CONNECTIVITY SETUP
#==============================================================================

# Initial network connectivity check
x=10
if ping -c 5 google.com; then
    x=0
fi

# WiFi connection loop with error handling
while [ $x != 0 ]
do
    echo "Scanning for WiFi networks..."
    iwctl station wlan0 scan
    iwctl station wlan0 get-networks
    echo -e "\n\n\n\nSSID :"
    read -r SSID
    echo "Password :"
    read -r PASSWORD
    
    # Attempt WiFi connection
    iwctl station wlan0 connect "$SSID" --passphrase="$PASSWORD"
    t=$?
    sleep 10
    
    # Test internet connectivity
    ping -c 5 google.com 
    x=$?
    
    # Provide feedback on connection status
    if [ $t != 0 ]; then
        echo -e "\n\n\nNot connected !\n\n\n"
    elif [ $x != 0 ]; then
        echo -e "\n\n\nConnected but no network !\n\n\n"
    fi
done

#==============================================================================
# DISK PARTITIONING AND FILESYSTEM SETUP
#==============================================================================

# Discover NVMe disks
mapfile -t nvme_disks < <(ls /dev/nvme*n1 2>/dev/null)
nvme_count=${#nvme_disks[@]}

if [ "$nvme_count" -eq 0 ]; then
    echo "No NVMe disks found on this system. Exit"
    exit 1
elif [ "$nvme_count" -eq 1 ]; then
    # Single NVMe disk configuration
    disk1="${nvme_disks[0]}"
    echo "Single NVMe disk detected: $disk1"
    
    # Partition single disk: EFI + Swap + Root
    sgdisk -Z "$disk1"
    sgdisk -n 1:0:+2G -t 1:ef00 "$disk1"    # EFI partition
    sgdisk -n 2:0:+8G -t 2:8200 "$disk1"    # Swap partition
    sgdisk -n 3:0:0 -t 3:8300 "$disk1"      # Root partition

    # Create filesystems
    mkfs.fat -F32 "${disk1}p1"
    mkswap --label diskswap "${disk1}p2"
    mkfs.ext4 "${disk1}p3"

    # Mount filesystems
    mount "${disk1}p3" /mnt
    mount --mkdir "${disk1}p1" /mnt/boot
    swapon "${disk1}p2"

elif [ "$nvme_count" -eq 2 ]; then
    # Dual NVMe disk configuration
    echo "Two NVMe disks detected:"
    for i in "${!nvme_disks[@]}"; do
        echo "$((i+1)). ${nvme_disks[i]}"
    done
    
    # User disk selection with validation
    while true; do
        read -r -p "Which disk do you want to select as the primary disk? (1 or 2): " choice
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
                echo "Invalid choice. Please enter 1 or 2."
                ;;
        esac
    done
    
    echo "Primary disk (disk1): $disk1"
    echo "Secondary disk (disk2): $disk2"

    # Clear partition tables
    sgdisk -Z "$disk1"
    sgdisk -Z "$disk2"

    # Partition primary disk: EFI + Root
    sgdisk -n 1:0:+2G -t 1:ef00 "$disk1"       # EFI partition
    sgdisk -n 2:0:0 -t 3:8300 "$disk1"        # Root partition
    mkfs.fat -F32 "${disk1}p1"
    mkfs.ext4 "${disk1}p2"

    # Partition secondary disk: Swap + Data
    sgdisk -n 1:0:+8G -t 2:8200 "$disk2"      # Swap partition
    sgdisk -n 2:0:0 -t 3:8300 "$disk2"        # Data partition
    mkswap --label diskswap "${disk2}p1"
    mkfs.ext4 "${disk2}p2"

    # Mount all filesystems
    mount "${disk1}p2" /mnt
    mount --mkdir "${disk1}p1" /mnt/boot
    mount --mkdir "${disk2}p2" /mnt/data
    swapon "${disk2}p1"

else
    # Unsupported disk configuration
    echo "More than 2 NVMe disks detected. Found $nvme_count disks:"
    for disk in "${nvme_disks[@]}"; do
        echo "  $disk"
    done
    echo "This script only handles up to 2 NVMe disks. Exit"
    exit 1
fi

#==============================================================================
# PACKAGE MANAGER CONFIGURATION
#==============================================================================

# Copy custom pacman configuration
tee /etc/pacman.conf < CONFIG/pacman.conf

#==============================================================================
# BASE SYSTEM INSTALLATION
#==============================================================================

# Install base system with error handling
if pacstrap /mnt base linux linux-headers linux-firmware; then
    echo "pacstrap installation occurred without error."
else
    echo "pacstrap installation occurred with error."
fi
read -r -p "Press any key to continue..."

#==============================================================================
# SYSTEM CONFIGURATION PREPARATION
#==============================================================================

# Generate filesystem table
genfstab -U /mnt | tee -a  /mnt/etc/fstab

# Copy installation files to target system
mkdir /mnt/archinstall
cp -r ./* /mnt/archinstall && chmod -R 755 /mnt/archinstall/SCRIPT/*

# Copy pacman configuration to target system
tee /mnt/etc/pacman.conf < CONFIG/pacman.conf

#==============================================================================
# CHROOT EXECUTION
#==============================================================================

# Execute first configuration script in chroot environment
arch-chroot /mnt bash /archinstall/SCRIPT/firstscript.sh

#==============================================================================
# CLEANUP AND REBOOT
#==============================================================================

# Unmount all filesystems and reboot
umount -a
reboot
