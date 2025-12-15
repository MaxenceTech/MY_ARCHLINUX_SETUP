#!/bin/bash

#==============================================================================
# Second Configuration Script (Post-Installation Setup)
#==============================================================================
# Description: Post-installation configuration script for desktop environment,
#              applications, gaming support, and advanced system features
# Author: MaxenceTech
# Usage: Run after completing firstscript.sh and rebooting
# Prerequisites: Completed base system installation, network connectivity
#==============================================================================

#==============================================================================
# NETWORK CONNECTIVITY VERIFICATION
#==============================================================================

# Verify and establish network connectivity
x=10
if ping -c 5 google.com; then
    x=0
fi

# WiFi connection setup if needed
while [ $x != 0 ]
do
    echo "Configuring WiFi connection..."
    sudo nmcli device wifi list
    echo -e "\n\n\n\nSSID :"
    read -r SSID
    sudo nmcli device wifi connect "$SSID" --ask
    t=$?
    sleep 10
    ping -c 5 google.com 
    x=$?
    if [ $t != 0 ]; then
        echo -e "\n\n\nNot connected !\n\n\n"
    elif [ $x != 0 ]; then
        echo -e "\n\n\nConnected but no network !\n\n\n"
    fi
done

#==============================================================================
# Check if secureboot is enabled
#==============================================================================

if [ $(sudo sbctl status | grep "Setup Mode" | grep -c "Disabled") -gt 0 ] && [ $(sudo sbctl status | grep "Secure Boot" | grep -c "Enabled") -gt 0 ]; then
	echo "Secure boot enabled and not in setup mode. Pass !"
else
	echo "Secure boot not enabled or in setup mode. Aborting !"
	exit 1
fi

# Exit on any error, undefined variables, and pipe failures
set -euo pipefail

#==============================================================================
# SYSTEM TIME AND HOSTNAME CONFIGURATION
#==============================================================================

# Configure system timezone
sudo timedatectl set-timezone Europe/Paris
sudo systemctl enable systemd-timesyncd

# Set hostname with validation
x=10
while [ $x != 0 ]
do
    echo "Nom Machine :"
    read -r hostnamevar
    # Basic hostname validation (RFC 1123 compliant)
    if [[ "$hostnamevar" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]] && [ ${#hostnamevar} -ge 1 ] && [ ${#hostnamevar} -le 63 ]; then
        sudo hostnamectl set-hostname "$hostnamevar"
        x=$?
    else
        echo "Invalid hostname. Use 1-63 characters (letters, numbers, hyphens only, no leading/trailing hyphens)."
        x=1
    fi
done

# Update hosts file
echo "127.0.0.1 localhost
::1 localhost
127.0.1.1 $hostnamevar" | sudo tee -a /etc/hosts

#==============================================================================
# PACKAGE INSTALLATION TRACKING
#==============================================================================

# Initialize error tracking for package installations
pacmanerror=0

#==============================================================================
# SYSTEM UPDATE
#==============================================================================

# Update system packages
echo "Updating system packages..."
sudo pacman -Syu --noconfirm
pacmanerror=$((pacmanerror + $?))

#==============================================================================
# AUR HELPER INSTALLATION
#==============================================================================
sudo perl -i.bak -pe 'if (/^OPTIONS=/ && s/(?<!\!)debug/!debug/) { $found=1 } END { exit 1 unless $found }' /etc/makepkg.conf
# Install Yay AUR helper
echo "Installing AUR helper (yay)..."
cd /tmp || exit 1
git clone https://aur.archlinux.org/yay.git
cd yay || exit 1
makepkg -si --noconfirm 

cd ~ || exit 1
yay -Syu --noconfirm

# Initialize yay error tracking
yayerror=0

#==============================================================================
# DISPLAY SERVER INSTALLATION
#==============================================================================

# Install Wayland support
echo "Installing Wayland display server..."
sudo pacman -S wayland lib32-wayland wayland-protocols --noconfirm
pacmanerror=$((pacmanerror + $?))

# Install Xorg support (for compatibility)
echo "Installing Xorg display server..."
sudo pacman -S xorg-server xorg-apps xorg-xwayland xorg-xlsclients --noconfirm
pacmanerror=$((pacmanerror + $?))

#==============================================================================
# GRAPHICS DRIVERS INSTALLATION
#==============================================================================

# Install Intel graphics drivers
echo "Installing Intel graphics drivers..."
sudo pacman -S mesa lib32-mesa mesa-utils intel-media-driver libva-utils libvpl vpl-gpu-rt \
    vulkan-icd-loader lib32-vulkan-icd-loader vulkan-intel lib32-vulkan-intel \
    vulkan-mesa-implicit-layers lib32-vulkan-mesa-implicit-layers vulkan-tools --noconfirm
pacmanerror=$((pacmanerror + $?))

# Install NVIDIA graphics drivers
echo "Installing NVIDIA graphics drivers..."
sudo pacman -S nvidia-open nvidia-utils lib32-nvidia-utils nvidia-settings libxnvctrl --noconfirm
pacmanerror=$((pacmanerror + $?))

echo '# Enable runtime PM for NVIDIA VGA/3D controller devices on adding device
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="auto"

# Enable runtime PM for NVIDIA VGA/3D controller devices on driver bind
ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="auto"

# Disable runtime PM for NVIDIA VGA/3D controller devices on driver unbind
ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="on"
ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="on"' | sudo tee /etc/udev/rules.d/90-prime-powermanagement.rules

echo 'options nvidia "NVreg_DynamicPowerManagement=0x03" NVreg_UsePageAttributeTable=1' | sudo tee /etc/modprobe.d/80-nvidia.conf

sudo mkinitcpio-editor -a nvidia nvidia_modeset nvidia_uvm nvidia_drm

sudo tee /etc/pacman.d/hooks/nvidia.hook << 'EOF'
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
# You can remove package(s) that don't apply to your config, e.g. if you only use nvidia-open you can remove nvidia-lts as a Target
Target=nvidia
Target=nvidia-open
# If running a different kernel, modify below to match
Target=linux

[Action]
Description=Updating NVIDIA module in initcpio
Depends=mkinitcpio
When=PostTransaction
NeedsTargets
Exec=/bin/sh -c 'while read -r trg; do case $trg in linux*) exit 0; esac; done; /usr/bin/mkinitcpio -P'
EOF

sudo systemctl enable nvidia-powerd.service

# Add OpenCL Support

sudo pacman -S clinfo opencl-nvidia lib32-opencl-nvidia cuda intel-compute-runtime ocl-icd opencl-headers --noconfirm
pacmanerror=$((pacmanerror + $?))
yay -S  ncurses5-compat-libs --noconfirm
yayerror=$((yayerror + $?))

echo "/usr/lib" | sudo tee /etc/ld.so.conf.d/00-usrlib.conf

# Add custom prime-run command (with opencl support redirection)

echo '#!/bin/bash
exec env OCL_ICD_FILENAMES=nvidia.icd:intel.icd __NV_PRIME_RENDER_OFFLOAD=1 __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/10_nvidia.json MESA_VK_DEVICE_SELECT=10de:27a0 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only "$@"' | sudo tee /usr/local/bin/prime-run
sudo chmod 755 /usr/local/bin/prime-run

# Dbus

sudo pacman -S dbus --noconfirm
pacmanerror=$((pacmanerror + $?))

# bluetooth

sudo pacman -S bluez bluez-utils --noconfirm
pacmanerror=$((pacmanerror + $?))
sudo systemctl enable bluetooth.service

# Audio system and opti
sudo pacman -S alsa-utils alsa-plugins alsa-firmware sof-firmware alsa-ucm-conf \
    pipewire lib32-pipewire wireplumber pipewire-alsa pipewire-pulse pamixer \
    pipewire-jack lib32-pipewire-jack --noconfirm
pacmanerror=$((pacmanerror + $?))
sudo usermod -a -G audio "$USER"
echo "high-priority = yes
nice-level = -11

realtime-scheduling = yes
realtime-priority = 5" | sudo tee /etc/pulse/daemon.conf

# Printing support
sudo pacman -S cups cups-pdf avahi nss-mdns ghostscript gsfonts foomatic-db-engine \
    foomatic-db foomatic-db-ppds gutenprint foomatic-db-gutenprint-ppds usbutils --noconfirm
pacmanerror=$((pacmanerror + $?))

sudo systemctl enable avahi-daemon.service

sudo sed -i 's/resolve/mdns_minimal [NOTFOUND=return] resolve/g' /etc/nsswitch.conf

sudo systemctl enable cups.socket

# GNOME desktop environment
sudo pacman -S dmidecode gnome gnome-tweaks gnome-shell-extensions \
    xdg-desktop-portal xdg-desktop-portal-gnome power-profiles-daemon \
    gnome-themes-extra fwupd --noconfirm
pacmanerror=$((pacmanerror + $?))
yay -S reversal-icon-theme-git --noconfirm
yayerror=$((yayerror + $?))

sudo sed -i -E 's/^(auth[[:space:]]+optional[[:space:]]+pam_gnome_keyring\.so)/\1 only_if=gdm/' /etc/pam.d/gdm-password 
sudo sed -i -E 's/^(session[[:space:]]+optional[[:space:]]+pam_gnome_keyring\.so)[[:space:]]+auto_start/\1 only_if=gdm/' /etc/pam.d/gdm-password

sudo systemctl enable gdm.service

#MSI-EC
yay -S msi-ec-dkms-git --noconfirm
yayerror=$((yayerror + $?))

echo "msi-ec" | sudo tee /etc/modules-load.d/msi-ec.conf

#Gnome-randr
yay -S gnome-randr-rust --noconfirm
yayerror=$((yayerror + $?))


#acpid
sudo pacman -S acpid --noconfirm
pacmanerror=$((pacmanerror + $?))
sudo cp -r /archinstall/SCRIPT/ACPID/* /etc/acpi
sudo chmod +x /etc/acpi/handler.sh
sudo chmod +x /etc/acpi/SCRIPT/*
sudo systemctl enable --now acpid.service

# QEMU/KVM virtualization
echo "softdep nvidia pre: vfio-pci" | sudo tee /etc/modprobe.d/30-vfio.conf
sudo pacman -S qemu-full qemu-img libvirt virt-install virt-manager virt-viewer \
    edk2-ovmf dnsmasq swtpm guestfs-tools libosinfo --noconfirm
pacmanerror=$((pacmanerror + $?))
sudo mkinitcpio-editor -a kvm kvm_intel virtio virtio_blk virtio_pci virtio_net vfio vfio_iommu_type1 vfio_pci
sudo systemctl enable libvirtd.service
echo "options kvm_intel nested=1" | sudo tee /etc/modprobe.d/20-kvm-intel.conf
sudo usermod -aG kvm "$USER"
sudo usermod -aG libvirt "$USER"
echo 'export LIBVIRT_DEFAULT_URI="qemu:///system"' >> ~/.bashrc
echo 'export LIBVIRT_DEFAULT_URI="qemu:///system"' >> ~/.zshrc 
sudo setfacl -R -b /var/lib/libvirt/images/
sudo setfacl -R -m "u:${USER}:rwX" /var/lib/libvirt/images/
sudo setfacl -m "d:u:${USER}:rwx" /var/lib/libvirt/images/

sudo cat /archinstall/CONFIG/createatlasos11vm | sudo tee /usr/local/bin/createatlasos11vm > /dev/null
sudo chmod +x /usr/local/bin/createatlasos11vm

# Fix keyboard layout
sudo localectl set-x11-keymap fr

# Java
sudo pacman -S java-runtime-common jre-openjdk --noconfirm
pacmanerror=$((pacmanerror + $?))

# Pare-feu

sudo pacman -S firewalld --noconfirm
pacmanerror=$((pacmanerror + $?))
sudo systemctl enable --now firewalld.service
sleep 5
sudo firewall-cmd --zone=public --remove-service ssh --permanent

while :; do
  read -p "Do you want to add $SSID as a home network ? (y/n) " yn
	case $yn in 
		y | Y) echo ok, we will proceed;
  			nmcli connection modify $SSID connection.zone home;
	 		read -r -p "$SSID is now a home network. Press any key to continue...";
      		break;;
		n | N) read -r -p "No changes made. Press any key to continue...";
      		break;;
		*) read -r -p "Invalid answer. No changes made. Press any key to continue...";;
	esac
done

# SSD Optimisation

sudo pacman -S util-linux --noconfirm
pacmanerror=$((pacmanerror + $?))

sudo systemctl enable fstrim.timer


# Essential applications
sudo pacman -S gparted speech-dispatcher libreoffice-still-fr file-roller zip unzip p7zip ttf-dejavu kdenlive obs-studio \
    unrar python-pip tk gimp inkscape bolt hunspell-fr noto-fonts-emoji blender cdrtools ttf-fira-code ttf-liberation lib32-fontconfig qbittorrent --noconfirm
pacmanerror=$((pacmanerror + $?))
yay -S vscodium-bin --noconfirm
yayerror=$((yayerror + $?))

yay -S librewolf-bin --noconfirm
yayerror=$((yayerror + $?))

yay -S mullvad-vpn-bin --noconfirm
yayerror=$((yayerror + $?))

echo 'export PATH="$PATH:/home/mux/.local/bin"' >> ~/.bashrc
echo 'export PATH="$PATH:/home/mux/.local/bin"' >> ~/.zshrc 

# Android file system support (grouped)
sudo pacman -S mtpfs gvfs-mtp gvfs-gphoto2 libmtp --noconfirm
pacmanerror=$((pacmanerror + $?))

# Android Studio
yay -S android-studio --noconfirm
yayerror=$((yayerror + $?))

# Disable coredump

sudo mkdir /etc/systemd/coredump.conf.d
echo "[Coredump]
Storage=none
ProcessSizeMax=0" | sudo tee /etc/systemd/coredump.conf.d/99-custom.conf

# Creation des repertoires utilisateurs

sudo pacman -S xdg-user-dirs --noconfirm
pacmanerror=$((pacmanerror + $?))

# ZSH
yay -S zsh zsh-completions zsh-theme-powerlevel10k-git  ttf-meslo-nerd-font-powerlevel10k zsh-autosuggestions zsh-history-substring-search zsh-syntax-highlighting --noconfirm
yayerror=$((yayerror + $?))


# ZSH plugins installation with error handling
echo "Installing ZSH plugins..."
sudo mkdir /usr/share/zsh/plugins/plugins_sudo_zsh
sudo wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/plugins/sudo/sudo.plugin.zsh -O /usr/share/zsh/plugins/plugins_sudo_zsh/zsh_sudo_plugin.zsh

sudo mkdir /usr/share/zsh/plugins/colored-man-pages
sudo wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/plugins/colored-man-pages/colored-man-pages.plugin.zsh -O /usr/share/zsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh

cat /archinstall/CONFIG/.zshrc > ~/.zshrc
cat /archinstall/CONFIG/.p10k.zsh > ~/.p10k.zsh

# Nano Color + tricks
sudo cat /archinstall/CONFIG/nanorc | sudo tee /etc/nanorc > /dev/null

# Fix group
sudo usermod -a -G sys "$USER"
sudo usermod -a -G lp "$USER"

# Fix power

echo '#!/bin/bash

# Read the value from /sys/class/power_supply/ADP1/online
online_status=$(cat /sys/class/power_supply/ADP1/online)

# Check the value and run different scripts based on it
if [ "$online_status" -eq 0 ]; then
    exec /etc/acpi/SCRIPT/a-unplug.sh
else
    # Run the script for when online status is 1 (plugged in)
    exec /etc/acpi/SCRIPT/a-plug.sh
fi
' | sudo tee /usr/local/bin/power-detect 
sudo chmod 700 /usr/local/bin/power-detect
echo "%wheel ALL=(root) NOPASSWD: /usr/local/bin/power-detect" | sudo tee -a /etc/sudoers

echo "[Desktop Entry]
Name=power-detect
GenericName=power detect and apply settings
Exec=sudo /usr/local/bin/power-detect
Terminal=false
Type=Application" | sudo tee /etc/xdg/autostart/power-detect.desktop

# Nvidia overclock on boot

yay -S python-nvidia-ml-py  --noconfirm
yayerror=$((yayerror + $?))


echo '#!/usr/bin/env python

from pynvml import *

nvmlInit()

# This sets the GPU to adjust - if this gives you errors or you have multiple GPUs, set to 1 or try other values
myGPU = nvmlDeviceGetHandleByIndex(0)

nvmlDeviceSetGpuLockedClocks(myGPU, 210, 2640)

# The GPU clock offset value should replace "000" in the line below.
nvmlDeviceSetGpcClkVfOffset(myGPU, 220)

# The memory clock offset should be **multiplied by 2** to replace the "000" below
# For example, an offset of 500 means inserting a value of 1000 in the next line
nvmlDeviceSetMemClkVfOffset(myGPU, 1200)
' | sudo tee /usr/local/bin/nvidia-oc.py
sudo chmod +x /usr/local/bin/nvidia-oc.py

echo "[Unit]
Description=Set up Nvidia settings
Wants=basic.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/nvidia-oc.py


[Install]
WantedBy=network.target" | sudo tee /etc/systemd/system/nvidia-oc.service

sudo systemctl enable nvidia-oc.service 

# /data permission
if [ -d /data ]; then
    sudo groupadd datausers
    sudo usermod -aG datausers "$USER"
    sudo chown root:datausers /data
    sudo chmod 775 /data
    sudo chmod g+s /data
    sudo mkdir /data/qbittorrent
    sudo chown root:datausers /data/qbittorrent
    sudo chmod 775 /data/qbittorrent
    sudo chmod g+s /data/qbittorrent
    sudo mkdir /data/libvirt_images
    sudo setfacl -R -b /data/libvirt_images
    sudo setfacl -R -m "u:${USER}:rwX" /data/libvirt_images
    sudo setfacl -m "d:u:${USER}:rwx" /data/libvirt_images
    ln -s /data/qbittorrent ~/SSD-qBittorrent
    sudo ln -s /data/libvirt_images /var/lib/libvirt/secondssd_images
fi


# Wayland support enable 

yay -S qt5-wayland qt6-wayland libdecor --noconfirm
yayerror=$((yayerror + $?))

echo 'LIBVIRT_DEFAULT_URI="qemu:///system"
MOZ_ENABLE_WAYLAND=1
QT_QPA_PLATFORM="wayland;xcb"
CLUTTER_BACKEND=wayland
SDL_VIDEODRIVER="wayland,x11"
XDG_SESSION_TYPE=wayland
MESA_VK_DEVICE_SELECT=8086:a78b
SUDO_EDITOR=nano
OCL_ICD_FILENAMES=intel.icd:nvidia.icd
__EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json
__GLX_VENDOR_LIBRARY_NAME=mesa' | sudo tee -a /etc/environment

sudo tee /usr/local/bin/setpci-latency.sh > /dev/null << 'EOF'
#!/bin/sh
# Set PCI latency timers
setpci -v -s '*:*' latency_timer=20
setpci -v -s '0:0' latency_timer=0
setpci -v -d "*:*:04xx" latency_timer=80
EOF
sudo chmod +x /usr/local/bin/setpci-latency.sh


echo "[Unit]
Description=Set PCI Device Latency Timers
After=sysinit.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/setpci-latency.sh

[Install]
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/setpci-latency.service
sudo systemctl enable setpci-latency.service

echo '<driconf>
   <device>
       <application name="Default">
           <option name="vblank_mode" value="0" />
       </application>
   </device>
</driconf>' | sudo tee /etc/drirc

echo "vm.max_map_count = 2147483642" | sudo tee /etc/sysctl.d/80-gamecompatibility.conf

# Looking-glass
cd /tmp || exit 1
curl --connect-timeout 10 --retry 10 --retry-delay 10 https://looking-glass.io/artifact/B7/source --output lookinglass.tar.xz
tar -xf lookinglass.tar.xz
cd /tmp/looking-glass-B7 || exit 1
mkdir client/build
cd client/build || exit 1
cmake -DENABLE_X11=no -DENABLE_LIBDECOR=ON ../
sudo make install
cd /tmp/looking-glass-B7/module/ || exit 1
sudo dkms install "."
echo "options kvmfr static_size_mb=64" | sudo tee /etc/modprobe.d/90-kvmfr.conf
echo "kvmfr" | sudo tee /etc/modules-load.d/kvmfr.conf
echo "SUBSYSTEM==\"kvmfr\", GROUP=\"kvm\", MODE=\"0660\"" | sudo tee /etc/udev/rules.d/99-kvmfr.rules
echo 'cgroup_device_acl = [
    "/dev/null", "/dev/full", "/dev/zero",
    "/dev/random", "/dev/urandom",
    "/dev/ptmx", "/dev/kvm",
    "/dev/userfaultfd", "/dev/kvmfr0"
]' | sudo tee -a /etc/libvirt/qemu.conf
echo "user = \"$(whoami)\"" | sudo tee -a /etc/libvirt/qemu.conf

#OBS Plugin Installation
cd /tmp/looking-glass-B7 || exit 1
mkdir obs/build
cd obs/build  || exit 1
cmake -DUSER_INSTALL=1 ../
make install

echo '[input]
captureOnFocus=yes
escapeKey=KEY_RIGHTSHIFT
rawMouse=yes

[spice]
clipboard=yes' | sudo tee /etc/looking-glass-client.ini

# Script Transparent Huge Page

sudo mkdir /etc/libvirt/hooks
sudo cat /archinstall/CONFIG/qemu | sudo tee /etc/libvirt/hooks/qemu > /dev/null
sudo chmod +x /etc/libvirt/hooks/qemu

#Fix Upower
sudo sed -i 's/^CriticalPowerAction=.*$/CriticalPowerAction=PowerOff/' /etc/UPower/UPower.conf
sudo sed -i 's/^PercentageLow=.*$/PercentageLow=20.0/' /etc/UPower/UPower.conf
sudo sed -i 's/^PercentageCritical=.*$/PercentageCritical=12.0/' /etc/UPower/UPower.conf
sudo sed -i 's/^PercentageAction=.*$/PercentageAction=8.0/' /etc/UPower/UPower.conf

# no hibernate

sudo mkdir /etc/systemd/sleep.conf.d
echo "[Sleep]
AllowHibernation=no
AllowHybridSleep=no
AllowSuspendThenHibernate=no" | sudo tee /etc/systemd/sleep.conf.d/no-hibernate.conf

sudo mkdir /etc/systemd/logind.conf.d
echo "[Login]
HibernateKeyIgnoreInhibited=no" | sudo tee /etc/systemd/logind.conf.d/no-hibernate.conf

# delete useless tools
sudo rm -rf /archinstall
sudo rm /usr/local/bin/mkinitcpio-editor

# Security Improve
sudo passwd --lock root
sudo sed -i.bak '0,/^auth/s/^auth/auth optional pam_faildelay.so delay=4000000\n&/' /etc/pam.d/system-login

sudo pacman -S usbguard --noconfirm
sudo sed -i "s/^IPCAllowedUsers=root/& $USER/" /etc/usbguard/usbguard-daemon.conf
sudo sed -i 's/^PresentControllerPolicy=.*/PresentControllerPolicy=apply-policy/' /etc/usbguard/usbguard-daemon.conf
sudo usbguard generate-policy | sudo tee -a /etc/usbguard/rules.conf
sudo systemctl enable --now usbguard-dbus.service

sudo tee /etc/polkit-1/rules.d/70-allow-usbguard.rules << 'EOF'
// Allow users in wheel group to communicate with USBGuard
polkit.addRule(function(action, subject) {
    if ((action.id == "org.usbguard.Policy1.listRules" ||
         action.id == "org.usbguard.Policy1.appendRule" ||
         action.id == "org.usbguard.Policy1.removeRule" ||
         action.id == "org.usbguard.Devices1.applyDevicePolicy" ||
         action.id == "org.usbguard.Devices1.listDevices" ||
         action.id == "org.usbguard1.getParameter" ||
         action.id == "org.usbguard1.setParameter") &&
        subject.active == true && subject.local == true &&
        subject.isInGroup("wheel")) {
            return polkit.Result.YES;
    }
});
EOF

gsettings set org.gnome.desktop.privacy usb-protection true
gsettings set org.gnome.desktop.privacy usb-protection-level always

sudo mkinitcpio -p linux

if [ "$yayerror" -eq 0 ]; then
    echo "Every yay installation occurred without error."
else
    echo "There was an error in one or more yay installations."
fi

if [ "$pacmanerror" -eq 0 ]; then
    echo "Every pacman installation occurred without error."
else
    echo "There was an error in one or more pacman installations."
fi

read -r -p "Press any key to continue..."

set +euo pipefail

yay -Scc --noconfirm
yes | LANG=C sudo pacman -Scc
go clean -cache

sleep 20

sudo reboot
