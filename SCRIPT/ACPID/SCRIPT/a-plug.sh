#!/bin/bash

#==============================================================================
# AC Adapter Plugged Script
#==============================================================================
# Description: Power management script executed when AC adapter is connected
#              Switches system to high-performance mode
# Author: MaxenceTech
# Usage: Called automatically by ACPI handler when adapter is plugged in
#==============================================================================

# Configure MSI-EC for performance mode
echo turbo | tee /sys/devices/platform/msi-ec/shift_mode
echo auto | tee /sys/devices/platform/msi-ec/fan_mode

# Set CPU governors to performance mode
echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference
echo 0 | tee /sys/devices/system/cpu/cpu*/power/energy_perf_bias

# Configure display for high refresh rate
runuser -l "$(last | cut -f 1 -d " " | sed '1p;d')" -c 'gnome-randr modify eDP-1 --mode 2560x1600@240.014'

# Restore saved brightness if available
if [ -f /tmp/brightness-saved ]; then
    tee /sys/class/backlight/intel_backlight/brightness < /tmp/brightness-saved
fi

# Wait for system to stabilize
sleep 5

# Deblock TDP after unplug-plug
systemctl restart nvidia-powerd.service

# Set power profile to performance mode
powerprofilesctl set performance
