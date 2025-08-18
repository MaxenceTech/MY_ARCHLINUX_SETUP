#!/bin/bash

# Exit on any error, undefined variables, and pipe failures  
set -euo pipefail

pacmanerror=0
# Update system first
pacman -Syu --noconfirm
pacmanerror=$((pacmanerror + $?))

# Base system packages (grouped)
pacman -S nano base-devel openssh networkmanager wpa_supplicant wireless_tools \
    netctl dialog iputils man git --noconfirm
pacmanerror=$((pacmanerror + $?))

# Enable NetworkManager
systemctl enable NetworkManager
mv /archinstall/SCRIPT/aurinstall.sh /usr/local/bin/aurinstall
mv /archinstall/SCRIPT/mkinitcpio-editor.sh /usr/local/bin/mkinitcpio-editor
sed -i 's/^#\(fr_FR.UTF-8\s*UTF-8\)/\1/' /etc/locale.gen
locale-gen
echo "LANG=fr_FR.UTF-8" > /etc/locale.conf
echo "KEYMAP=fr-pc" > /etc/vconsole.conf
echo "Mot de passe root :"
x=10
while [ $x != 0 ]
do
    passwd
    x=$?
done
echo "Nom d'utisateur :"
x=10
while [ $x != 0 ]
do
    read -r nomutilisateur
    useradd -m -g users -G wheel "$nomutilisateur"
    x=$?
done
echo "Mot de passe utiliateur :"
x=10
while [ $x != 0 ]
do
    passwd "$nomutilisateur"
    x=$?
done

sed -i 's/^#\s*\(%wheel\s*ALL=(ALL:ALL)\s*ALL\)/\1/' /etc/sudoers

# Fix ACPI error
mkdir /etc/initcpio/acpi_override
cp /archinstall/CONFIG/ssdt1.aml /etc/initcpio/acpi_override

hooksvar=$(grep -v  -n "^#" /etc/mkinitcpio.conf | grep 'HOOKS=')
ligne="${hooksvar%:*}"
sed -i "$((ligne)) d" /etc/mkinitcpio.conf
sed -i "$((ligne-1)) a HOOKS=(systemd autodetect modconf block keyboard sd-vconsole filesystems fsck acpi_override)" /etc/mkinitcpio.conf

# Tweaks
echo "vm.swappiness=2
vm.dirty_bytes = 4294967296
vm.dirty_background_bytes = 2147483648
vm.vfs_cache_pressure=50" | tee /etc/sysctl.d/99-ramtweaks.conf

mkinitcpio-editor -a xe lz4
pacman -S efibootmgr intel-ucode --noconfirm
pacmanerror=$((pacmanerror + $?))
PARTUUIDGREP=$(grep "/ " /etc/fstab | cut -f 1 -d " ")
bootctl install
echo "default  arch.conf
timeout  6
console-mode max
editor   no" | tee /boot/loader/loader.conf
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
bootctl update
systemctl enable systemd-boot-update.service

if [ "$pacmanerror" -eq 0 ]; then
    echo "Every pacman installation occurred without error."
else
    echo "There was an error in one or more pacman installations."
fi

read -r -p "Press any key to continue..."
