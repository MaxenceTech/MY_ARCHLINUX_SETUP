#!/bin/bash

#==============================================================================
# AC Adapter Unplugged Script
#==============================================================================
# Description: Power management script executed when AC adapter is disconnected
#              Switches system to power-saving mode to extend battery life
# Author: MaxenceTech
# Usage: Called automatically by ACPI handler when adapter is unplugged
#==============================================================================

# Set power profile to power saver mode
powerprofilesctl set power-saver

# Wait for system to stabilize
sleep 5


#Enable turno boost
echo 0 | tee /sys/devices/system/cpu/intel_pstate/no_turbo

# Configure MSI-EC for power saving mode
echo eco | tee /sys/devices/platform/msi-ec/shift_mode
echo auto | tee /sys/devices/platform/msi-ec/fan_mode

# Set CPU governors to power saving mode
echo powersave | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
echo power | tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference
echo 15 | tee /sys/devices/system/cpu/cpu*/power/energy_perf_bias

# Switch display to lower refresh rate for power saving
runuser -l "$(last | cut -f 1 -d " " | sed '1p;d')" -c 'gnome-randr modify eDP-1 --mode 2560x1600@60.008'

# Save current brightness and reduce it for battery conservation
tee /tmp/brightness-saved < /sys/class/backlight/intel_backlight/brightness
echo 22000 | tee /sys/class/backlight/intel_backlight/brightness
