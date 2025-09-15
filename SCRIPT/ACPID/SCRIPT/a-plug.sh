#!/bin/bash

#==============================================================================
# AC Adapter Plugged Script
#==============================================================================
# Description: Power management script executed when AC adapter is connected
#              Switches system to high-performance mode
# Author: MaxenceTech
# Usage: Called automatically by ACPI handler when adapter is plugged in
#==============================================================================

# Set power profile to performance mode
powerprofilesctl set performance

# Wait for system to stabilize
sleep 5

#Enable turno boost
echo 0 | tee /sys/devices/system/cpu/intel_pstate/no_turbo

# Configure MSI-EC for performance mode
echo turbo | tee /sys/devices/platform/msi-ec/shift_mode
echo auto | tee /sys/devices/platform/msi-ec/fan_mode

# Set CPU governors to performance mode
echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference
echo 0 | tee /sys/devices/system/cpu/cpu*/power/energy_perf_bias

# Configure display for high refresh rate
runuser -l "$(last | cut -f 1 -d " " | sed '1p;d')" -c 'gnome-randr modify $(gnome-randr | grep "eDP" | cut -f 1 -d " "  | sed -n '2p') --mode 2560x1600@240.014'

# Restore saved brightness if available
if [ -f /tmp/brightness-saved ]; then
    tee /sys/class/backlight/intel_backlight/brightness < /tmp/brightness-saved
fi

# Deblock TDP after unplug-plug
systemctl restart nvidia-powerd.service
