#!/bin/bash

# ACPI Event Handler Script
# This script processes ACPI events and executes appropriate actions
# Handles AC adapter events for power management

# Exit on any error, undefined variables, and pipe failures
set -euo pipefail

# Constants
readonly SCRIPT_DIR="/etc/acpi/SCRIPT"
readonly LOG_TAG="ACPI-HANDLER"

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    logger -t "$LOG_TAG" "[$level] $message"
}

# Execute power management script with error handling
execute_power_script() {
    local script="$1"
    local script_path="$SCRIPT_DIR/$script"
    
    if [[ -x "$script_path" ]]; then
        log_message "INFO" "Executing power management script: $script"
        if ! "$script_path"; then
            log_message "ERROR" "Failed to execute $script (exit code: $?)"
            return 1
        fi
        log_message "INFO" "Successfully executed $script"
    else
        log_message "ERROR" "Power management script not found or not executable: $script_path"
        return 1
    fi
}

# Handle AC adapter events
handle_ac_adapter() {
    local device="$1"
    local state="$2"
    
    case "$device" in
        ACPI0003:00)
            case "$state" in
                00000000)
                    log_message "INFO" "AC adapter unplugged - switching to battery mode"
                    execute_power_script "a-unplug.sh"
                    ;;
                00000001)
                    log_message "INFO" "AC adapter plugged in - switching to AC mode"
                    execute_power_script "a-plug.sh"
                    ;;
                *)
                    log_message "WARNING" "Unknown AC adapter state: $state"
                    ;;
            esac
            ;;
        *)
            log_message "WARNING" "Unknown AC adapter device: $device"
            ;;
    esac
}

# Main event handler
main() {
    local event_group="${1:-}"
    local event_device="${2:-}"
    local event_id="${3:-}"
    local event_value="${4:-}"
    
    log_message "DEBUG" "ACPI event received: group=$event_group device=$event_device id=$event_id value=$event_value"
    
    case "$event_group" in
        ac_adapter)
            handle_ac_adapter "$event_device" "$event_value"
            ;;
        *)
            log_message "WARNING" "Unhandled ACPI event group: $event_group (device: $event_device)"
            ;;
    esac
}

# Execute main function with all provided arguments
main "$@"
