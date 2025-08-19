#!/bin/bash

# AC Adapter Unplugged Script  
# This script executes when AC power is disconnected
# Optimizes system for battery power saving

# Exit on any error, undefined variables, and pipe failures
set -euo pipefail

# Constants
readonly LOG_TAG="ACPI-UNPLUG"
readonly BACKLIGHT_PATH="/sys/class/backlight/intel_backlight"
readonly BRIGHTNESS_CACHE="/tmp/brightness-saved"
readonly BATTERY_BRIGHTNESS="22000"
readonly DISPLAY_MODE="2560x1600@60.008"

# Logging function
log_action() {
    local message="$1"
    logger -t "$LOG_TAG" "$message"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message"
}

# Set MSI EC power saving mode
configure_msi_ec() {
    log_action "Configuring MSI EC for power saving mode"
    
    local msi_ec_path="/sys/devices/platform/msi-ec"
    
    if [[ -d "$msi_ec_path" ]]; then
        echo "eco" | tee "$msi_ec_path/shift_mode" || log_action "Warning: Failed to set shift_mode"
        echo "auto" | tee "$msi_ec_path/fan_mode" || log_action "Warning: Failed to set fan_mode"
    else
        log_action "Warning: MSI EC interface not available"
    fi
}

# Configure CPU power saving settings
configure_cpu_powersave() {
    log_action "Configuring CPU for power saving mode"
    
    # Set CPU governor to powersave
    echo "powersave" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor || \
        log_action "Warning: Failed to set CPU governor"
    
    # Set energy performance preference to power saving
    echo "power" | tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference || \
        log_action "Warning: Failed to set energy performance preference"
    
    # Set energy performance bias to maximum power saving
    echo "15" | tee /sys/devices/system/cpu/cpu*/power/energy_perf_bias || \
        log_action "Warning: Failed to set energy performance bias"
}

# Configure display for battery mode
configure_display() {
    log_action "Configuring display for battery power mode"
    
    # Get the current user (last logged in user)
    local current_user
    current_user=$(last | head -n1 | cut -f1 -d' ')
    
    if [[ -n "$current_user" && "$current_user" != "reboot" ]]; then
        # Set lower refresh rate display mode to save power
        if runuser -l "$current_user" -c "gnome-randr modify eDP-1 --mode $DISPLAY_MODE" 2>/dev/null; then
            log_action "Display mode set to $DISPLAY_MODE for power saving"
        else
            log_action "Warning: Failed to set display mode or gnome-randr not available"
        fi
        
        # Save current brightness and reduce it
        if [[ -r "$BACKLIGHT_PATH/brightness" ]]; then
            if tee "$BRIGHTNESS_CACHE" < "$BACKLIGHT_PATH/brightness" 2>/dev/null; then
                log_action "Current brightness saved to cache"
            else
                log_action "Warning: Failed to save current brightness"
            fi
            
            if echo "$BATTERY_BRIGHTNESS" | tee "$BACKLIGHT_PATH/brightness" 2>/dev/null; then
                log_action "Brightness reduced to $BATTERY_BRIGHTNESS for battery mode"
            else
                log_action "Warning: Failed to reduce brightness"
            fi
        else
            log_action "Warning: Backlight control not available"
        fi
    else
        log_action "Warning: No active user session found"
    fi
}

# Configure power profile for battery mode
configure_power_profile() {
    log_action "Setting power profile to power saver mode"
    
    # Wait a moment for other settings to stabilize
    sleep 5
    
    if command -v powerprofilesctl >/dev/null 2>&1; then
        if powerprofilesctl set power-saver; then
            log_action "Power profile set to power-saver"
        else
            log_action "Warning: Failed to set power profile"
        fi
    else
        log_action "Warning: powerprofilesctl not available"
    fi
}

# Main execution
main() {
    log_action "AC adapter unplugged - configuring battery mode"
    
    configure_msi_ec
    configure_cpu_powersave
    configure_display
    configure_power_profile
    
    log_action "Battery power configuration completed"
}

# Execute main function
main "$@"
