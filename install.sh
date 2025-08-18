#!/bin/bash

# Exit on any error, undefined variables, and pipe failures
set -euo pipefail

# Cleanup any existing mounts (ignore errors if not mounted)
umount /dev/nvme0n1p1 2>/dev/null || true
umount /dev/nvme0n1p2 2>/dev/null || true
swapoff /dev/nvme0n1p3 2>/dev/null || true

loadkeys fr-pc

x=10
if ping -c 5 google.com; then
    x=0
fi
while [ $x != 0 ]
do
    iwctl station wlan0 scan
    iwctl station wlan0 get-networks
    echo -e "\n\n\n\nSSID :"
    read -r SSID
    echo "Password :"
    read -r PASSWORD
    iwctl station wlan0 connect "$SSID" --passphrase="$PASSWORD"
    t=$?
    sleep 10
    if ping -c 5 google.com; then
        x=0
    else
        x=$?
    fi
    if [ $t != 0 ]; then
        echo -e "\n\n\nNot connected !\n\n\n"
    elif [ $x != 0 ]; then
        echo -e "\n\n\nConnected but no network !\n\n\n"
    fi
done

# Find all NVMe disks
mapfile -t nvme_disks < <(ls /dev/nvme*n1 2>/dev/null)
nvme_count=${#nvme_disks[@]}

if [ "$nvme_count" -eq 0 ]; then
    echo "No NVMe disks found on this system. Exit"
    exit 1
elif [ "$nvme_count" -eq 1 ]; then
    # Only one NVMe disk found
    disk1="${nvme_disks[0]}"
    echo "Single NVMe disk detected: $disk1"
    
    sgdisk -Z /dev/nvme0n1
    sgdisk -n 1:0:+2G -t 1:ef00 /dev/nvme0n1
    sgdisk -n 2:0:+8G -t 2:8200 /dev/nvme0n1
    sgdisk -n 3:0:0 -t 3:8300 /dev/nvme0n1

    mkfs.fat -F32 /dev/nvme0n1p1
    mkswap --label diskswap /dev/nvme0n1p2
    mkfs.ext4 /dev/nvme0n1p3

    mount /dev/nvme0n1p3 /mnt
    mount --mkdir /dev/nvme0n1p1 /mnt/boot
    swapon /dev/nvme0n1p2

elif [ "$nvme_count" -eq 2 ]; then
    # Exactly two NVMe disks found
    echo "Two NVMe disks detected:"
    for i in "${!nvme_disks[@]}"; do
        echo "$((i+1)). ${nvme_disks[i]}"
    done
    
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

    sgdisk -Z "$disk1"
    sgdisk -Z "$disk2"

    sgdisk -n 1:0:+2G -t 1:ef00 "$disk1"
    sgdisk -n 2:0:0 -t 3:8300 "$disk1"
    mkfs.fat -F32 "${disk1}p1"
    mkfs.ext4 "${disk1}p2"

    sgdisk -n 1:0:+8G -t 2:8200 "$disk2"
    sgdisk -n 2:0:0 -t 3:8300 "$disk2"
    mkswap --label diskswap "${disk2}p1"
    mkfs.ext4 "${disk2}p2"

    mount "${disk1}p2" /mnt
    mount --mkdir "${disk1}p1" /mnt/boot
    mount --mkdir "${disk2}p2" /mnt/data
    swapon "${disk2}p1"

else
    # More than two NVMe disks found
    echo "More than 2 NVMe disks detected. Found $nvme_count disks:"
    for disk in "${nvme_disks[@]}"; do
        echo "  $disk"
    done
    echo "This script only handles up to 2 NVMe disks. Exit"
    exit 1
fi

# Copy pacman configuration
tee /etc/pacman.conf < CONFIG/pacman.conf

pacstrap /mnt base linux linux-headers linux-firmware

if pacstrap /mnt base linux linux-headers linux-firmware; then
    echo "pacstrap installation occurred without error."
else
    echo "pacstrap installation occurred with error."
fi
read -r -p "Press any key to continue..."

genfstab -U /mnt | tee -a  /mnt/etc/fstab

mkdir /mnt/archinstall
cp -r ./* /mnt/archinstall && chmod -R 755 /mnt/archinstall/SCRIPT/*

tee /mnt/etc/pacman.conf < CONFIG/pacman.conf

arch-chroot /mnt bash /archinstall/SCRIPT/firstscript.sh

umount -a
reboot