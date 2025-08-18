#!/bin/bash

#MSI-EC
echo eco | tee /sys/devices/platform/msi-ec/shift_mode
echo auto | tee /sys/devices/platform/msi-ec/fan_mode

echo powersave | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
echo power | tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference
echo 15 | tee /sys/devices/system/cpu/cpu*/power/energy_perf_bias

#Change HZ
runuser -l $(last | cut -f 1 -d " " | sed '1p;d') -c 'gnome-randr modify eDP-1 --mode 2560x1600@60.008'
cat /sys/class/backlight/intel_backlight/brightness | tee /tmp/brightness-saved
echo 22000 | tee /sys/class/backlight/intel_backlight/brightness

sleep 5

#power-profile-deamon
powerprofilesctl set power-saver
