#!/bin/bash

set -euo pipefail

if [ $(sudo sbctl status | grep "Setup Mode" | grep -c "Enabled") -gt 0 ]; then
	sudo sbctl create-keys
	sudo sbctl enroll-keys -m -f
	sudo sbctl sign-all -g
else
	echo "Not in setup mode ! Exiting !"
	exit 1
fi

echo '[Trigger]
Type = Package
Operation = Install
Operation = Upgrade
Target = systemd

[Action]
Description = Gracefully upgrading systemd-boot...
When = PostTransaction
Exec = /usr/bin/systemctl restart systemd-boot-update.service' | sudo tee /etc/pacman.d/hooks/95-systemd-boot.hook


sudo tee /etc/pacman.d/hooks/80-secureboot.hook << 'EOF'
[Trigger]
Type = Path
Operation = Install
Operation = Upgrade
Target = usr/lib/systemd/boot/efi/systemd-boot*.efi

[Action]
Description = Signing systemd-boot EFI binary for Secure Boot
When = PostTransaction
Exec = /bin/sh -c 'while read -r f; do sbctl sign -s "$f"; done;'
Depends = sh
NeedsTargets
EOF

sudo reboot
