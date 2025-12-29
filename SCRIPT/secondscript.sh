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

# Add OpenCL Support

sudo pacman -S clinfo ocl-icd opencl-headers --noconfirm
pacmanerror=$((pacmanerror + $?))
yay -S intel-compute-runtime-legacy --noconfirm
yayerror=$((yayerror + $?))

echo "/usr/lib" | sudo tee /etc/ld.so.conf.d/00-usrlib.conf

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
    gnome-themes-extra --noconfirm
pacmanerror=$((pacmanerror + $?))
yay -S reversal-icon-theme-git --noconfirm
yayerror=$((yayerror + $?))

sudo sed -i -E 's/^(auth[[:space:]]+optional[[:space:]]+pam_gnome_keyring\.so)/\1 only_if=gdm/' /etc/pam.d/gdm-password 
sudo sed -i -E 's/^(session[[:space:]]+optional[[:space:]]+pam_gnome_keyring\.so)[[:space:]]+auto_start/\1 only_if=gdm/' /etc/pam.d/gdm-password

sudo systemctl enable gdm.service

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
sudo pacman -S gparted speech-dispatcher libreoffice-still-fr file-roller zip unzip p7zip ttf-dejavu cdrkit \
    unrar python-pip tk gimp inkscape bolt hunspell-fr noto-fonts-emoji ttf-fira-code ttf-liberation lib32-fontconfig --noconfirm
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

# Wayland support enable 

yay -S qt5-wayland qt6-wayland libdecor --noconfirm
yayerror=$((yayerror + $?))

echo 'MOZ_ENABLE_WAYLAND=1
QT_QPA_PLATFORM="wayland;xcb"
CLUTTER_BACKEND=wayland
SDL_VIDEODRIVER="wayland,x11"
XDG_SESSION_TYPE=wayland
SUDO_EDITOR=nano
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
