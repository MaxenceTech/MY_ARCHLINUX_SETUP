#!/bin/bash

#==============================================================================
# AC Adapter Unplugged Script
#==============================================================================
# Description: Power management script executed when AC adapter is disconnected
#              and gamemode is running
# Author: MaxenceTech
# Usage: Called automatically by ACPI handler when adapter is unplugged
#============================================================================

# Set power profile to performance mode
powerprofilesctl set performance

# Wait for system to stabilize
sleep 5

#Disable turno boost
echo 1 | tee /sys/devices/system/cpu/intel_pstate/no_turbo

# Configure MSI-EC for performance mode
echo comfort | tee /sys/devices/platform/msi-ec/shift_mode
echo auto | tee /sys/devices/platform/msi-ec/fan_mode

# Set CPU governors to performance mode
echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference
echo 6 | tee /sys/devices/system/cpu/cpu*/power/energy_perf_bias

# Switch display to lower refresh rate for power saving
runuser -l "$(last | cut -f 1 -d " " | sed '1p;d')" -c 'gnome-randr modify eDP-1 --mode 2560x1600@60.008'

# Deblock TDP after unplug-plug
systemctl restart nvidia-powerd.service
