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

sudo systemctl enable gdm.service

#MSI-EC
yay -S msi-ec-dkms-git --noconfirm
yayerror=$((yayerror + $?))

echo "msi-ec" | sudo tee /etc/modules-load.d/msi-ec.conf

# mcontrolcenter
yay -S mcontrolcenter-bin --noconfirm
yayerror=$((yayerror + $?))

cat /archinstall/CONFIG/MControlCenter.conf > ~/.config/MControlCenter.conf
sudo cp /usr/share/applications/mcontrolcenter.desktop /etc/xdg/autostart/

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
sudo pacman -S gparted speech-dispatcher libreoffice-still-fr file-roller zip unzip p7zip ttf-dejavu kdenlive obs-studio cdrkit seahorse \
    unrar python-pip tk gimp inkscape bolt hunspell-fr noto-fonts-emoji blender ttf-fira-code qbittorrent firefox --noconfirm
pacmanerror=$((pacmanerror + $?))
yay -S vscodium-bin --noconfirm
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
gamemodeout="$(runuser -l "$(last | cut -f 1 -d " " | sed "1p;d")" -c "LANG=C gamemoded -s")"

if echo "$gamemodeout" | grep -wiq "active"; then
    gamemodestatus=1   # actif
else   
    gamemodestatus=0  # inactif
fi


# Check the value and run different scripts based on it
if [ "$online_status" -eq 0 ]; then
    if [ "$gamemodestatus" -eq 1 ] || [ "$1" = "-g" ]; then
        # Run the script for when online status is 0 (unplugged) and in (or will be in) gamemode
        exec /etc/acpi/SCRIPT/gamemode-unplug.sh
    else
        # Run the script for when online status is 0 (unplugged)
        exec /etc/acpi/SCRIPT/a-unplug.sh
    fi
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
    ln -s /data/qbittorrent ~/SSD-qBittorrent
fi


# Wayland support enable 

yay -S qt5-wayland qt6-wayland libdecor --noconfirm
yayerror=$((yayerror + $?))

echo 'MOZ_ENABLE_WAYLAND=1
QT_QPA_PLATFORM="wayland;xcb"
CLUTTER_BACKEND=wayland
SDL_VIDEODRIVER="wayland,x11"
XDG_SESSION_TYPE=wayland
MESA_VK_DEVICE_SELECT=8086:a78b
GSK_RENDERER=ngl
SUDO_EDITOR=nano
OCL_ICD_FILENAMES=intel.icd:nvidia.icd
__EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json
__GLX_VENDOR_LIBRARY_NAME=mesa
GAMEMODERUNEXEC="prime-run env vblank_mode=0 LD_BIND_NOW=1"' | sudo tee -a /etc/environment

# Gaming support
sudo pacman -S steam prismlauncher ttf-liberation lib32-fontconfig \
    gamemode lib32-gamemode joyutils --noconfirm
pacmanerror=$((pacmanerror + $?))

yay -S protonup-qt --noconfirm
yayerror=$((yayerror + $?))

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

#Gamemode
sudo usermod -a -G gamemode "$USER"

echo '[general]
; The reaper thread will check every 5 seconds for exited clients, for config file changes, and for the CPU/iGPU power balance
reaper_freq=5

; The desired governor is used when entering GameMode instead of "performance"
desiredgov=performance
; The default governor is used when leaving GameMode instead of restoring the original value
;defaultgov=powersave

; The desired platform profile is used when entering GameMode instead of "performance"
desiredprof=performance
; The default platform profile is used when leaving GameMode instead of restoring the original value
;defaultgov=low-power

; The iGPU desired governor is used when the integrated GPU is under heavy load
igpu_desiredgov=performance
; Threshold to use to decide when the integrated GPU is under heavy load.
; This is a ratio of iGPU Watts / CPU Watts which is used to determine when the
; integraged GPU is under heavy enough load to justify switching to
; igpu_desiredgov.  Set this to -1 to disable all iGPU checking and always
; use desiredgov for games.
igpu_power_threshold=-1

; GameMode can change the scheduler policy to SCHED_ISO on kernels which support it (currently
; not supported by upstream kernels). Can be set to "auto", "on" or "off". "auto" will enable
; with 4 or more CPU cores. "on" will always enable. Defaults to "off".
softrealtime=off

; GameMode can renice game processes. You can put any value between 0 and 20 here, the value
; will be negated and applied as a nice value (0 means no change). Defaults to 0.
; To use this feature, the user must be added to the gamemode group (and then rebooted):
; sudo usermod -aG gamemode $(whoami)
renice=0

; By default, GameMode adjusts the iopriority of clients to BE/0, you can put any value
; between 0 and 7 here (with 0 being highest priority), or one of the special values
; "off" (to disable) or "reset" (to restore Linux default behavior based on CPU priority),
; currently, only the best-effort class is supported thus you cannot set it here
ioprio=0

; Sets whether gamemode will inhibit the screensaver when active
; Defaults to 1
inhibit_screensaver=1

; Sets whether gamemode will disable split lock mitigation when active
; Defaults to 1
disable_splitlock=1

[filter]
; If "whitelist" entry has a value(s)
; gamemode will reject anything not in the whitelist
;whitelist=RiseOfTheTombRaider

; Gamemode will always reject anything in the blacklist
;blacklist=HalfLife3
;    glxgears

[gpu]
; Here Be Dragons!
; Warning: Use these settings at your own risk
; Any damage to hardware incurred due to this feature is your responsibility and yours alone
; It is also highly recommended you try these settings out first manually to find the sweet spots

; Setting this to the keyphrase "accept-responsibility" will allow gamemode to apply GPU optimisations such as overclocks
;apply_gpu_optimisations=0

; The DRM device number on the system (usually 0), ie. the number in /sys/class/drm/card0/
;gpu_device=0

; Nvidia specific settings
; Requires the coolbits extension activated in nvidia-xconfig
; This corresponds to the desired GPUPowerMizerMode
; "Adaptive"=0 "Prefer Maximum Performance"=1 and "Auto"=2
; See NV_CTRL_GPU_POWER_MIZER_MODE and friends in https://github.com/NVIDIA/nvidia-settings/blob/master/src/libXNVCtrl/NVCtrl.h
;nv_powermizer_mode=1

; These will modify the core and mem clocks of the highest perf state in the Nvidia PowerMizer
; They are measured as Mhz offsets from the baseline, 0 will reset values to default, -1 or unset will not modify values
;nv_core_clock_mhz_offset=0
;nv_mem_clock_mhz_offset=0

; AMD specific settings
; Requires a relatively up to date AMDGPU kernel module
; See: https://dri.freedesktop.org/docs/drm/gpu/amdgpu.html#gpu-power-thermal-controls-and-monitoring
; It is also highly recommended you use lm-sensors (or other available tools) to verify card temperatures
; This corresponds to power_dpm_force_performance_level, "manual" is not supported for now
;amd_performance_level=high

[cpu]
; Parking or Pinning can be enabled with either "yes", "true" or "1" and disabled with "no", "false" or "0".
; Either can also be set to a specific list of cores to park or pin, comma separated list where "-" denotes
; a range. E.g "park_cores=1,8-15" would park cores 1 and 8 to 15.
; The default is uncommented is to disable parking but enable pinning. If either is enabled the code will
; currently only properly autodetect Ryzen 7900x3d, 7950x3d and Intel CPU:s with E- and P-cores.
; For Core Parking, user must be added to the gamemode group (not required for Core Pinning):
; sudo usermod -aG gamemode $(whoami)
park_cores=no
pin_cores=yes

[supervisor]
; This section controls the new gamemode functions gamemode_request_start_for and gamemode_request_end_for
; The whilelist and blacklist control which supervisor programs are allowed to make the above requests
;supervisor_whitelist=
;supervisor_blacklist=

; In case you want to allow a supervisor to take full control of gamemode, this option can be set
; This will only allow gamemode clients to be registered by using the above functions by a supervisor client
;require_supervisor=0

[custom]
; Custom scripts (executed using the shell) when gamemode starts and ends
start=notify-send "GameMode started"
    sudo /usr/local/bin/power-detect -g

end=notify-send "GameMode ended"
    sudo /usr/local/bin/power-detect

; Timeout for scripts (seconds). Scripts will be killed if they do not complete within this time.
;script_timeout=10' | sudo tee /etc/gamemode.ini

#Fix Upower
sudo sed -i 's/^CriticalPowerAction=.*$/CriticalPowerAction=PowerOff/' /etc/UPower/UPower.conf
sudo sed -i 's/^PercentageLow=.*$/PercentageLow=20.0/' /etc/UPower/UPower.conf
sudo sed -i 's/^PercentageCritical=.*$/PercentageCritical=12.0/' /etc/UPower/UPower.conf
sudo sed -i 's/^PercentageAction=.*$/PercentageAction=8.0/' /etc/UPower/UPower.conf

# Virtualbox
sudo pacman -S virtualbox virtualbox-host-modules-arch virtualbox-guest-iso --noconfirm
pacmanerror=$((pacmanerror + $?))
yay -S virtualbox-ext-oracle --noconfirm
yayerror=$((yayerror + $?))

sudo usermod -a -G vboxusers "$USER"
gsettings set org.gnome.mutter.wayland xwayland-grab-access-rules "['VirtualBox Machine']"

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

# Update fonts cache
sudo fc-cache --force
sudo fc-cache-32 --force

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

sudo rm -rf /var/cache/pacman/pkg/download-*
yay -Scc --noconfirm
yes | LANG=C sudo pacman -Scc
go clean -cache

sleep 20

sudo reboot
