#!/bin/bash

#MSI-EC
echo turbo | tee /sys/devices/platform/msi-ec/shift_mode
echo auto | tee /sys/devices/platform/msi-ec/fan_mode

echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference
echo 0 | tee /sys/devices/system/cpu/cpu*/power/energy_perf_bias

#Screen
runuser -l "$(last | cut -f 1 -d " " | sed '1p;d')" -c 'gnome-randr modify eDP-1 --mode 2560x1600@240.014'
if [ -f /tmp/brightness-saved ]; then
    tee /sys/class/backlight/intel_backlight/brightness < /tmp/brightness-saved
fi

sleep 5

#power-profile-deamon
powerprofilesctl set performance