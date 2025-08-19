#!/bin/bash

# AC Adapter Plugged Script
# This script executes when AC power is connected
# Optimizes system for performance mode

# Exit on any error, undefined variables, and pipe failures
set -euo pipefail

# Constants
readonly LOG_TAG="ACPI-PLUG"
readonly BACKLIGHT_PATH="/sys/class/backlight/intel_backlight"
readonly BRIGHTNESS_CACHE="/tmp/brightness-saved"
readonly DISPLAY_MODE="2560x1600@240.014"

# Logging function
log_action() {
    local message="$1"
    logger -t "$LOG_TAG" "$message"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message"
}

# Set MSI EC performance mode
configure_msi_ec() {
    log_action "Configuring MSI EC for performance mode"
    
    local msi_ec_path="/sys/devices/platform/msi-ec"
    
    if [[ -d "$msi_ec_path" ]]; then
        echo "turbo" | tee "$msi_ec_path/shift_mode" || log_action "Warning: Failed to set shift_mode"
        echo "auto" | tee "$msi_ec_path/fan_mode" || log_action "Warning: Failed to set fan_mode"
    else
        log_action "Warning: MSI EC interface not available"
    fi
}

# Configure CPU performance settings
configure_cpu_performance() {
    log_action "Configuring CPU for maximum performance"
    
    # Set CPU governor to performance
    echo "performance" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor || \
        log_action "Warning: Failed to set CPU governor"
    
    # Set energy performance preference
    echo "performance" | tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference || \
        log_action "Warning: Failed to set energy performance preference"
    
    # Set energy performance bias to maximum performance
    echo "0" | tee /sys/devices/system/cpu/cpu*/power/energy_perf_bias || \
        log_action "Warning: Failed to set energy performance bias"
}

# Configure display settings
configure_display() {
    log_action "Configuring display for AC power mode"
    
    # Get the current user (last logged in user)
    local current_user
    current_user=$(last | head -n1 | cut -f1 -d' ')
    
    if [[ -n "$current_user" && "$current_user" != "reboot" ]]; then
        # Set high refresh rate display mode
        if runuser -l "$current_user" -c "gnome-randr modify eDP-1 --mode $DISPLAY_MODE" 2>/dev/null; then
            log_action "Display mode set to $DISPLAY_MODE"
        else
            log_action "Warning: Failed to set display mode or gnome-randr not available"
        fi
        
        # Restore brightness if saved
        if [[ -f "$BRIGHTNESS_CACHE" ]]; then
            if tee "$BACKLIGHT_PATH/brightness" < "$BRIGHTNESS_CACHE" 2>/dev/null; then
                log_action "Brightness restored from cache"
            else
                log_action "Warning: Failed to restore brightness"
            fi
        fi
    else
        log_action "Warning: No active user session found"
    fi
}

# Configure power profile
configure_power_profile() {
    log_action "Setting power profile to performance mode"
    
    # Wait a moment for other settings to stabilize
    sleep 5
    
    if command -v powerprofilesctl >/dev/null 2>&1; then
        if powerprofilesctl set performance; then
            log_action "Power profile set to performance"
        else
            log_action "Warning: Failed to set power profile"
        fi
    else
        log_action "Warning: powerprofilesctl not available"
    fi
}

# Main execution
main() {
    log_action "AC adapter plugged in - configuring performance mode"
    
    configure_msi_ec
    configure_cpu_performance
    configure_display
    configure_power_profile
    
    log_action "AC power configuration completed"
}

# Execute main function
main "$@"