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

# Load disk configuration
source /archinstall/CONFIG/disk_config.conf

# Update mkinitcpio hooks for ACPI support and encryption
echo "Updating mkinitcpio configuration..."
hooksvar=$(grep -v  -n "^#" /etc/mkinitcpio.conf | grep 'HOOKS=')
ligne="${hooksvar%:*}"
sed -i "$((ligne)) d" /etc/mkinitcpio.conf
# Add encrypt hook for LUKS support
sed -i "$((ligne-1)) a HOOKS=(systemd autodetect modconf block keyboard sd-vconsole sd-encrypt filesystems fsck acpi_override)" /etc/mkinitcpio.conf

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
pacman -S efibootmgr intel-ucode systemd-ukify --noconfirm
pacmanerror=$((pacmanerror + $?))

# Get partition UUIDs for bootloader configuration
ROOT_UUID=$(awk '$2 == "/" {print $1}' /etc/fstab)
SWAP_UUID=$(awk '$3 == "swap" {print $1}' /etc/fstab)

# Get the actual device UUIDs for LUKS
if [ "$DISK_COUNT" -eq 1 ]; then
    ROOT_DEVICE_UUID=$(blkid -s UUID -o value "$ROOT_DEVICE")
    SWAP_DEVICE_UUID=$(blkid -s UUID -o value "$SWAP_DEVICE")
elif [ "$DISK_COUNT" -eq 2 ]; then
    ROOT_DEVICE_UUID=$(blkid -s UUID -o value "$ROOT_DEVICE")
    SWAP_DEVICE_UUID=$(blkid -s UUID -o value "$SWAP_DEVICE")
fi

echo "Root partition UUID: $ROOT_UUID"
echo "Root device UUID: $ROOT_DEVICE_UUID"
echo "Swap device UUID: $SWAP_DEVICE_UUID"

#==============================================================================
# SECURE BOOT SETUP WITH SYSTEMD-UKIFY
#==============================================================================

echo "Setting up Secure Boot with systemd-ukify..."

# Create directory for Secure Boot keys
mkdir -p /etc/secureboot/keys
cd /etc/secureboot/keys

# Generate Secure Boot keys
echo "Generating Secure Boot keys..."

# Generate Platform Key (PK)
openssl req -new -x509 -newkey rsa:2048 -subj "/CN=Platform Key/" -keyout PK.key -out PK.crt -days 7300 -nodes -sha256

# Generate Key Exchange Key (KEK)
openssl req -new -x509 -newkey rsa:2048 -subj "/CN=Key Exchange Key/" -keyout KEK.key -out KEK.crt -days 7300 -nodes -sha256

# Generate Database Key (db)
openssl req -new -x509 -newkey rsa:2048 -subj "/CN=Signature Database key/" -keyout db.key -out db.crt -days 7300 -nodes -sha256

# Convert certificates to proper format for UEFI
openssl x509 -in PK.crt -out PK.pem -outform PEM
openssl x509 -in KEK.crt -out KEK.pem -outform PEM
openssl x509 -in db.crt -out db.pem -outform PEM

# Set appropriate permissions
chmod 400 *.key
chmod 444 *.crt *.pem

echo "Secure Boot keys generated successfully."

# Configure systemd-ukify
echo "Configuring systemd-ukify..."
mkdir -p /etc/kernel

# Build command line based on disk configuration
if [ "$DISK_COUNT" -eq 1 ]; then
    CMDLINE_BASE="root=UUID=$ROOT_DEVICE_UUID rootfstype=ext4 rd.luks.name=$ROOT_DEVICE_UUID=cryptroot rd.luks.name=$SWAP_DEVICE_UUID=cryptswap resume=/dev/mapper/cryptswap"
elif [ "$DISK_COUNT" -eq 2 ]; then
    DATA_DEVICE_UUID=$(blkid -s UUID -o value "$DATA_DEVICE")
    CMDLINE_BASE="root=UUID=$ROOT_DEVICE_UUID rootfstype=ext4 rd.luks.name=$ROOT_DEVICE_UUID=cryptroot rd.luks.name=$SWAP_DEVICE_UUID=cryptswap rd.luks.name=$DATA_DEVICE_UUID=cryptdata resume=/dev/mapper/cryptswap"
fi

CMDLINE_COMMON="$CMDLINE_BASE hibernate.compressor=lz4 rw quiet mitigations=auto,nosmt nowatchdog tsc=reliable clocksource=tsc intel_iommu=on iommu=pt vt.global_cursor_default=0 zswap.enabled=1 zswap.shrinker_enabled=1 zswap.compressor=lz4 zswap.max_pool_percent=12 zswap.zpool=zsmalloc"

cat > /etc/kernel/ukify.conf << EOF
[UKI]
Linux=/boot/vmlinuz-linux
Initrd=/boot/intel-ucode.img
Initrd=/boot/initramfs-linux.img
Cmdline=$CMDLINE_COMMON
SecureBootPrivateKey=/etc/secureboot/keys/db.key
SecureBootCertificate=/etc/secureboot/keys/db.crt

[EFI]
ImageId=arch
EOF

echo "systemd-ukify configuration completed."

# Create directory for Unified Kernel Images
mkdir -p /boot/EFI/Linux

# Install and configure systemd-boot
bootctl install

# Create bootloader configuration for systemd-ukify UKIs
echo "default  @saved
timeout  6
console-mode max
editor   no" | tee /boot/loader/loader.conf

#==============================================================================
# UNIFIED KERNEL IMAGE GENERATION
#==============================================================================

echo "Generating Unified Kernel Images with systemd-ukify..."

# Generate primary UKI with NVIDIA support
ukify build \
    --linux=/boot/vmlinuz-linux \
    --initrd=/boot/intel-ucode.img \
    --initrd=/boot/initramfs-linux.img \
    --cmdline="$CMDLINE_COMMON modprobe.blacklist=kvmfr video=HDMI-A-1:d video=DP-1:d video=DP-2:d" \
    --secureboot-private-key=/etc/secureboot/keys/db.key \
    --secureboot-certificate=/etc/secureboot/keys/db.crt \
    --output=/boot/EFI/Linux/arch-nvidia.efi

# Generate UKI for GPU passthrough
ukify build \
    --linux=/boot/vmlinuz-linux \
    --initrd=/boot/intel-ucode.img \
    --initrd=/boot/initramfs-linux.img \
    --cmdline="$CMDLINE_COMMON vfio-pci.ids=10de:27a0,10de:22bc" \
    --secureboot-private-key=/etc/secureboot/keys/db.key \
    --secureboot-certificate=/etc/secureboot/keys/db.crt \
    --output=/boot/EFI/Linux/arch-gpupassthrough.efi

# Generate fallback UKI
ukify build \
    --linux=/boot/vmlinuz-linux \
    --initrd=/boot/intel-ucode.img \
    --initrd=/boot/initramfs-linux-fallback.img \
    --cmdline="$CMDLINE_COMMON modprobe.blacklist=kvmfr video=HDMI-A-1:d video=DP-1:d video=DP-2:d" \
    --secureboot-private-key=/etc/secureboot/keys/db.key \
    --secureboot-certificate=/etc/secureboot/keys/db.crt \
    --output=/boot/EFI/Linux/arch-fallback.efi

echo "Unified Kernel Images generated successfully."

# Set up automatic UKI generation on kernel updates
mkdir -p /etc/kernel/install.d
cat > /etc/kernel/install.d/90-ukify.install << 'EOF'
#!/bin/bash
# Automatic UKI generation script for kernel updates

if [ "$1" = "add" ]; then
    KERNEL_VERSION="$2"
    KERNEL_IMAGE="$3"
    INITRD_IMAGE="/boot/initramfs-linux.img"
    FALLBACK_INITRD="/boot/initramfs-linux-fallback.img"
    
    # Read disk configuration
    source /archinstall/CONFIG/disk_config.conf
    ROOT_DEVICE_UUID=$(blkid -s UUID -o value "$ROOT_DEVICE")
    SWAP_DEVICE_UUID=$(blkid -s UUID -o value "$SWAP_DEVICE")
    
    # Build command line based on disk configuration
    if [ "$DISK_COUNT" -eq 1 ]; then
        CMDLINE_BASE="root=UUID=$ROOT_DEVICE_UUID rootfstype=ext4 rd.luks.name=$ROOT_DEVICE_UUID=cryptroot rd.luks.name=$SWAP_DEVICE_UUID=cryptswap resume=/dev/mapper/cryptswap"
    elif [ "$DISK_COUNT" -eq 2 ]; then
        DATA_DEVICE_UUID=$(blkid -s UUID -o value "$DATA_DEVICE")
        CMDLINE_BASE="root=UUID=$ROOT_DEVICE_UUID rootfstype=ext4 rd.luks.name=$ROOT_DEVICE_UUID=cryptroot rd.luks.name=$SWAP_DEVICE_UUID=cryptswap rd.luks.name=$DATA_DEVICE_UUID=cryptdata resume=/dev/mapper/cryptswap"
    fi
    
    CMDLINE_COMMON="$CMDLINE_BASE hibernate.compressor=lz4 rw quiet mitigations=auto,nosmt nowatchdog tsc=reliable clocksource=tsc intel_iommu=on iommu=pt vt.global_cursor_default=0 zswap.enabled=1 zswap.shrinker_enabled=1 zswap.compressor=lz4 zswap.max_pool_percent=12 zswap.zpool=zsmalloc"
    
    # Generate primary UKI
    ukify build \
        --linux="$KERNEL_IMAGE" \
        --initrd=/boot/intel-ucode.img \
        --initrd="$INITRD_IMAGE" \
        --cmdline="$CMDLINE_COMMON modprobe.blacklist=kvmfr video=HDMI-A-1:d video=DP-1:d video=DP-2:d" \
        --secureboot-private-key=/etc/secureboot/keys/db.key \
        --secureboot-certificate=/etc/secureboot/keys/db.crt \
        --output="/boot/EFI/Linux/arch-nvidia-${KERNEL_VERSION}.efi"
    
    # Create symlink for default
    ln -sf "arch-nvidia-${KERNEL_VERSION}.efi" "/boot/EFI/Linux/arch-nvidia.efi"
    
    # Generate fallback UKI
    ukify build \
        --linux="$KERNEL_IMAGE" \
        --initrd=/boot/intel-ucode.img \
        --initrd="$FALLBACK_INITRD" \
        --cmdline="$CMDLINE_COMMON modprobe.blacklist=kvmfr video=HDMI-A-1:d video=DP-1:d video=DP-2:d" \
        --secureboot-private-key=/etc/secureboot/keys/db.key \
        --secureboot-certificate=/etc/secureboot/keys/db.crt \
        --output="/boot/EFI/Linux/arch-fallback-${KERNEL_VERSION}.efi"
    
    ln -sf "arch-fallback-${KERNEL_VERSION}.efi" "/boot/EFI/Linux/arch-fallback.efi"
fi
EOF

chmod +x /etc/kernel/install.d/90-ukify.install

#==============================================================================
# SECURE BOOT KEY ENROLLMENT INSTRUCTIONS
#==============================================================================

echo "=============================================================================="
echo "IMPORTANT: SECURE BOOT KEY ENROLLMENT"
echo "=============================================================================="
echo ""
echo "Your Secure Boot keys have been generated and are located in:"
echo "/etc/secureboot/keys/"
echo ""
echo "After reboot, you MUST enroll these keys in your UEFI firmware:"
echo ""
echo "1. Copy the key files to a USB drive (formatted as FAT32):"
echo "   - PK.crt (Platform Key)"
echo "   - KEK.crt (Key Exchange Key)"  
echo "   - db.crt (Signature Database Key)"
echo ""
echo "2. Reboot and enter UEFI Setup (usually F2, F12, or DEL during boot)"
echo ""
echo "3. Navigate to Security settings and find Secure Boot options"
echo ""
echo "4. Enable Custom Mode or Advanced Secure Boot options"
echo ""
echo "5. Clear existing keys (if any) and enroll your custom keys:"
echo "   - First enroll db.crt (Database Key)"
echo "   - Then enroll KEK.crt (Key Exchange Key)"
echo "   - Finally enroll PK.crt (Platform Key) - THIS ENABLES SECURE BOOT"
echo ""
echo "6. Save settings and exit UEFI Setup"
echo ""
echo "Your system will now boot with Secure Boot enabled using your custom keys."
echo "=============================================================================="
echo ""

# Update bootloader and enable automatic updates
bootctl update || [[ $? -eq 1 ]]
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
