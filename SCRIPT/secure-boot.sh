#!/bin/bash

set -euo pipefail

if [ $(sudo sbctl status | grep "Setup Mode" | grep -c "Enabled") -gt 0 ]; then
	sudo sbctl create-keys
	sudo sbctl enroll-keys -m -f
	sudo sbctl verify | sed -E 's|^.* (/.+) is not signed$|sudo sbctl sign -s "\1"|e'
else
	echo "Not in setup mode ! Exiting !"
	exit 1
fi

echo "[Trigger]
Type = Package
Operation = Upgrade
Target = systemd

[Action]
Description = Gracefully upgrading systemd-boot...
When = PostTransaction
Exec = /usr/bin/systemctl restart systemd-boot-update.service" | sudo tee /etc/pacman.d/hooks/95-systemd-boot.hook

sbctlvar=$(sudo grep -v  -n "^#" /usr/share/libalpm/hooks/zz-sbctl.hook | grep 'Target' | tail -1)
ligne="${sbctlvar%:*}"
sudo sed -i "$((ligne)) a Target = usr/lib/systemd/boot/efi/systemd-boot*.efi" /usr/share/libalpm/hooks/zz-sbctl.hook


sudo reboot
