#!/bin/bash

# Mkinitcpio Module Editor
# This utility script manages kernel modules in /etc/mkinitcpio.conf
# Features: Add, remove, and list modules with validation and error handling

# Exit on any error, undefined variables, and pipe failures
set -euo pipefail

# Constants
readonly MKINITCONF="/etc/mkinitcpio.conf"
readonly SCRIPT_NAME="${0##*/}"
readonly BACKUP_SUFFIX=".backup.$(date +%s)"

# Validation and utility functions
validate_mkinitconf() {
    if [[ ! -f "$MKINITCONF" ]]; then
        echo "Error: $MKINITCONF not found!"
        exit 1
    fi
    
    if [[ ! -w "$MKINITCONF" ]]; then
        echo "Error: No write permission for $MKINITCONF!"
        exit 1
    fi
}

# Create backup of mkinitcpio.conf
create_backup() {
    local backup_file="${MKINITCONF}${BACKUP_SUFFIX}"
    if cp "$MKINITCONF" "$backup_file"; then
        echo "Backup created: $backup_file"
    else
        echo "Warning: Failed to create backup"
    fi
}

# Get the MODULES line from mkinitcpio.conf
get_modules_line() {
    grep -v "^#" "$MKINITCONF" | grep "^MODULES=" 2>/dev/null || {
        echo "Warning: No MODULES line found in $MKINITCONF"
        return 1
    }
}

# Extract modules from the MODULES line
extract_modules() {
    local modules_line
    if modules_line=$(get_modules_line); then
        # Remove 'MODULES=(' and trailing ')'
        echo "${modules_line#MODULES=(}" | sed 's/)$//'
    else
        echo ""
    fi
}

# Validate module names
validate_module_names() {
    local modules=("$@")
    local invalid_modules=()
    
    for module in "${modules[@]}"; do
        # Check if module name contains only valid characters
        if [[ ! "$module" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            invalid_modules+=("$module")
        fi
    done
    
    if [[ ${#invalid_modules[@]} -gt 0 ]]; then
        echo "Error: Invalid module names detected:"
        printf '  %s\n' "${invalid_modules[@]}"
        echo "Module names should contain only letters, numbers, hyphens, and underscores."
        exit 1
    fi
}

# Update the MODULES line in mkinitcpio.conf
update_modules() {
    local new_modules="$1"
    
    # Create backup before making changes
    create_backup
    
    local line_number
    line_number=$(grep -n "^MODULES=" "$MKINITCONF" | cut -d: -f1 2>/dev/null || echo "")
    
    if [[ -z "$line_number" ]]; then
        # If MODULES line doesn't exist, add it at the end
        echo "MODULES=($new_modules)" >> "$MKINITCONF"
        echo "MODULES line added to $MKINITCONF"
    else
        # Replace existing MODULES line
        sed -i "${line_number}s/.*/MODULES=($new_modules)/" "$MKINITCONF"
        echo "MODULES line updated in $MKINITCONF"
    fi
}

# Rebuild initramfs after module changes
rebuild_initramfs() {
    echo "Rebuilding initramfs..."
    if mkinitcpio -p linux; then
        echo "Initramfs rebuilt successfully!"
    else
        echo "Error: Failed to rebuild initramfs!"
        echo "Please check the module configuration and try again."
        exit 1
    fi
}

# Add modules to the configuration
add_modules() {
    local modules_to_add=("${@:2}")  # Skip the command parameter
    
    if [[ ${#modules_to_add[@]} -eq 0 ]]; then
        echo "Error: No modules specified to add."
        echo "Usage: $SCRIPT_NAME -a|--add <module1> [module2] ..."
        exit 1
    fi
    
    validate_module_names "${modules_to_add[@]}"
    
    local current_modules
    current_modules=$(extract_modules)
    
    # Convert current modules to array
    local -a current_array
    if [[ -n "$current_modules" ]]; then
        read -ra current_array <<< "$current_modules"
    else
        current_array=()
    fi
    
    # Add new modules if they don't already exist
    local -a final_modules=("${current_array[@]}")
    local added_count=0
    
    for module in "${modules_to_add[@]}"; do
        local already_exists=false
        for existing in "${current_array[@]}"; do
            if [[ "$existing" == "$module" ]]; then
                already_exists=true
                break
            fi
        done
        
        if [[ "$already_exists" == "false" ]]; then
            final_modules+=("$module")
            ((added_count++))
            echo "Adding module: $module"
        else
            echo "Module already exists: $module"
        fi
    done
    
    if [[ $added_count -gt 0 ]]; then
        update_modules "${final_modules[*]}"
        rebuild_initramfs
        echo "Successfully added $added_count module(s)."
    else
        echo "No new modules were added."
    fi
}

# Remove modules from the configuration
remove_modules() {
    local modules_to_remove=("${@:2}")  # Skip the command parameter
    
    if [[ ${#modules_to_remove[@]} -eq 0 ]]; then
        echo "Error: No modules specified to remove."
        echo "Usage: $SCRIPT_NAME -r|--remove <module1> [module2] ..."
        exit 1
    fi
    
    validate_module_names "${modules_to_remove[@]}"
    
    local current_modules
    current_modules=$(extract_modules)
    
    if [[ -z "$current_modules" ]]; then
        echo "No modules currently configured."
        return 0
    fi
    
    # Convert current modules to array
    local -a current_array
    read -ra current_array <<< "$current_modules"
    
    # Filter out modules to be removed
    local -a final_modules=()
    local removed_count=0
    
    for existing in "${current_array[@]}"; do
        local should_remove=false
        for remove_module in "${modules_to_remove[@]}"; do
            if [[ "$existing" == "$remove_module" ]]; then
                should_remove=true
                echo "Removing module: $remove_module"
                ((removed_count++))
                break
            fi
        done
        
        if [[ "$should_remove" == "false" ]]; then
            final_modules+=("$existing")
        fi
    done
    
    # Check for modules that weren't found
    for remove_module in "${modules_to_remove[@]}"; do
        local found=false
        for existing in "${current_array[@]}"; do
            if [[ "$existing" == "$remove_module" ]]; then
                found=true
                break
            fi
        done
        if [[ "$found" == "false" ]]; then
            echo "Module not found: $remove_module"
        fi
    done
    
    if [[ $removed_count -gt 0 ]]; then
        update_modules "${final_modules[*]}"
        rebuild_initramfs
        echo "Successfully removed $removed_count module(s)."
    else
        echo "No modules were removed."
    fi
}

# Display currently configured modules
print_modules() {
    local current_modules
    current_modules=$(extract_modules)
    
    echo "=== Current Kernel Modules Configuration ==="
    if [[ -n "$current_modules" && "$current_modules" != " " ]]; then
        echo "Configured modules: $current_modules"
        
        # Count modules
        local -a modules_array
        read -ra modules_array <<< "$current_modules"
        echo "Total modules: ${#modules_array[@]}"
    else
        echo "No modules currently configured in $MKINITCONF"
    fi
    echo "============================================"
}

# Display help information
show_help() {
    cat << EOF
$SCRIPT_NAME - Kernel Module Configuration Utility

DESCRIPTION:
    This script manages kernel modules in $MKINITCONF.
    It allows you to add, remove, and list modules with automatic
    initramfs rebuilding.

USAGE:
    $SCRIPT_NAME [OPTIONS] [MODULES...]

OPTIONS:
    -p, --print     Display currently configured modules
    -a, --add       Add one or more modules
    -r, --remove    Remove one or more modules  
    -h, --help      Display this help message

EXAMPLES:
    $SCRIPT_NAME -p
    $SCRIPT_NAME -a kvm vfio
    $SCRIPT_NAME -r kvm vfio
    $SCRIPT_NAME --add nvidia nvidia_drm
    $SCRIPT_NAME --remove old_module

NOTES:
    - Module names should contain only letters, numbers, hyphens, and underscores
    - A backup of $MKINITCONF is created before any modifications
    - The initramfs is automatically rebuilt after changes
    - Root privileges are required for modifications

EOF
}

# Main function to handle command line arguments
main() {
    # Check if running as root for modifications
    if [[ $EUID -ne 0 ]] && [[ "${1:-}" != "-p" ]] && [[ "${1:-}" != "--print" ]] && [[ "${1:-}" != "-h" ]] && [[ "${1:-}" != "--help" ]]; then
        echo "Error: Root privileges required for module modifications."
        echo "Use 'sudo $SCRIPT_NAME' or run as root."
        exit 1
    fi
    
    # Validate configuration file (except for help)
    if [[ "${1:-}" != "-h" ]] && [[ "${1:-}" != "--help" ]]; then
        validate_mkinitconf
    fi
    
    # Handle command line arguments
    if [[ $# -lt 1 ]]; then
        echo "Error: No command specified."
        show_help
        exit 1
    fi
    
    case "$1" in
        -a|--add)
            add_modules "$@"
            ;;
        -r|--remove)
            remove_modules "$@"
            ;;
        -p|--print)
            print_modules
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Error: Unknown command '$1'"
            echo "Use '$SCRIPT_NAME --help' for usage information."
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"
