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

# Set CPU governors to performance mode
echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference
echo 4 | tee /sys/devices/system/cpu/cpu*/power/energy_perf_bias
