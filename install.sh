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

# Set French keyboard layout
loadkeys fr-pc

while :; do
  read -p "The script will erase all yours NVME drives. Do you want to continue ? (y/n) " yn
	case $yn in 
		y | Y) echo ok, we will proceed;
      		break;;
		n | N) read -r -p "Exit. Press any key to continue...";
      		exit 1;;
		*) read -r -p "Invalid answer. Press any key to continue...";;
	esac
done

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

sleep 120

#==============================================================================
# HARDWARE CAPABILITY CHECK
#==============================================================================

# Check for AES-NI hardware acceleration support
echo "Checking for AES-NI hardware acceleration..."
if grep -q aes /proc/cpuinfo; then
    echo "AES-NI hardware acceleration is supported."
    AES_NI_AVAILABLE=true
else
    echo "Warning: AES-NI hardware acceleration not detected."
    AES_NI_AVAILABLE=false
fi

#==============================================================================
# LUKS ENCRYPTION FUNCTIONS
#==============================================================================

# Setup LUKS encryption with AES-NI optimization
setup_luks_partition() {
    local device="$1"
    local name="$2"
    
    echo "Setting up LUKS encryption for $device..."
    
    # Use AES-NI optimized cipher if available
    if [ "$AES_NI_AVAILABLE" = true ]; then
        CIPHER="aes-xts-plain64"
        echo "Using AES-NI optimized cipher: $CIPHER"
    else
        CIPHER="aes-xts-plain64"
        echo "Using standard cipher: $CIPHER"
    fi
    
    # Setup LUKS with optimal parameters for performance and security
    echo "Creating LUKS partition. You will be prompted for a passphrase."
    echo "Choose a strong passphrase - this protects your entire system!"
    
    cryptsetup luksFormat \
        --type luks2 \
        --cipher "$CIPHER" \
        --key-size 512 \
        --hash sha512 \
        --pbkdf argon2id \
        --pbkdf-time 2000 \
        --use-random \
        "$device"
    
    if [ $? -ne 0 ]; then
        echo "Error: LUKS formatting failed for $device"
        exit 1
    fi
    
    # Open the encrypted partition
    echo "Opening encrypted partition..."
    cryptsetup open "$device" "$name"
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to open encrypted partition $device"
        exit 1
    fi
    
    echo "LUKS encryption setup completed for $device -> /dev/mapper/$name"
}

#==============================================================================
# DISK PARTITIONING AND FILESYSTEM SETUP
#==============================================================================

lsblk -d -o NAME,MODEL,SIZE,TYPE | grep nvme

# Discover NVMe disks
mapfile -t nvme_disks < <(ls /dev/nvme*n1 2>/dev/null)
nvme_count=${#nvme_disks[@]}

if [ "$nvme_count" -eq 0 ]; then
    echo "No NVMe disks found on this system. Exit"
    exit 1
elif [ "$nvme_count" -eq 1 ]; then
    # Single NVMe disk configuration with LUKS encryption
    disk1="${nvme_disks[0]}"
    echo "Single NVMe disk detected: $disk1"
    
    # Partition single disk: EFI + Swap + Root (encrypted)
    sgdisk -Z "$disk1"
    sgdisk --set-alignment=2048 --align-end -n 1:0:+2G -t 1:ef00 "$disk1"    # EFI partition
    sgdisk --set-alignment=2048 --align-end -n 2:0:+72G -t 2:8200 "$disk1"    # Swap partition
    sgdisk --set-alignment=2048 --align-end -n 3:0:0 -t 3:8300 "$disk1"      # Root partition (to be encrypted)

    # Create EFI filesystem
    mkfs.fat -F32 "${disk1}p1"
    
    # Setup LUKS encryption for root partition
    setup_luks_partition "${disk1}p3" "cryptroot"
    
    # Create filesystem on encrypted root
    mkfs.ext4 /dev/mapper/cryptroot
    
    # Setup swap partition (also encrypted for security)
    setup_luks_partition "${disk1}p2" "cryptswap"
    mkswap /dev/mapper/cryptswap

    # Mount filesystems
    mount /dev/mapper/cryptroot /mnt
    mount --mkdir "${disk1}p1" /mnt/boot
    swapon /dev/mapper/cryptswap

elif [ "$nvme_count" -eq 2 ]; then
    # Dual NVMe disk configuration with LUKS encryption
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

    # Partition primary disk: EFI + Root (encrypted)
    sgdisk --set-alignment=2048 --align-end -n 1:0:+2G -t 1:ef00 "$disk1"       # EFI partition
    sgdisk --set-alignment=2048 --align-end -n 2:0:0 -t 2:8300 "$disk1"        # Root partition (to be encrypted)
    
    # Create EFI filesystem
    mkfs.fat -F32 "${disk1}p1"
    
    # Setup LUKS encryption for root partition
    setup_luks_partition "${disk1}p2" "cryptroot"
    mkfs.ext4 /dev/mapper/cryptroot

    # Partition secondary disk: Swap (encrypted) + Data (encrypted)
    sgdisk --set-alignment=2048 --align-end -n 1:0:+72G -t 1:8200 "$disk2"      # Swap partition
    sgdisk --set-alignment=2048 --align-end -n 2:0:0 -t 2:8300 "$disk2"        # Data partition
    
    # Setup LUKS encryption for swap and data partitions
    setup_luks_partition "${disk2}p1" "cryptswap"
    mkswap /dev/mapper/cryptswap
    
    setup_luks_partition "${disk2}p2" "cryptdata"
    mkfs.ext4 /dev/mapper/cryptdata

    # Mount all filesystems
    mount /dev/mapper/cryptroot /mnt
    mount --mkdir "${disk1}p1" /mnt/boot
    mount --mkdir /dev/mapper/cryptdata /mnt/data
    swapon /dev/mapper/cryptswap

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

# Install base system with encryption support
pacstrap /mnt base linux linux-headers linux-firmware cryptsetup

if [ "$?" -eq 0 ]; then
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

# Save disk and encryption configuration for chroot script
mkdir -p /mnt/archinstall/CONFIG
if [ "$nvme_count" -eq 1 ]; then
    echo "DISK_COUNT=1" > /mnt/archinstall/CONFIG/disk_config.conf
    echo "DISK1=${disk1}" >> /mnt/archinstall/CONFIG/disk_config.conf
    echo "ROOT_DEVICE=${disk1}p3" >> /mnt/archinstall/CONFIG/disk_config.conf
    echo "SWAP_DEVICE=${disk1}p2" >> /mnt/archinstall/CONFIG/disk_config.conf
elif [ "$nvme_count" -eq 2 ]; then
    echo "DISK_COUNT=2" > /mnt/archinstall/CONFIG/disk_config.conf
    echo "DISK1=${disk1}" >> /mnt/archinstall/CONFIG/disk_config.conf
    echo "DISK2=${disk2}" >> /mnt/archinstall/CONFIG/disk_config.conf
    echo "ROOT_DEVICE=${disk1}p2" >> /mnt/archinstall/CONFIG/disk_config.conf
    echo "SWAP_DEVICE=${disk2}p1" >> /mnt/archinstall/CONFIG/disk_config.conf
    echo "DATA_DEVICE=${disk2}p2" >> /mnt/archinstall/CONFIG/disk_config.conf
fi
echo "AES_NI_AVAILABLE=${AES_NI_AVAILABLE}" >> /mnt/archinstall/CONFIG/disk_config.conf

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
umount -a 2>/dev/null || true
reboot
