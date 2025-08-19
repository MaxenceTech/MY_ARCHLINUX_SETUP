# Bash Script Audit - Implementation Guide

## 1. Immediate Security Fixes

### Fix 1: Secure Password Handling in install.sh

**File:** `install.sh` (line 25)

**Replace:**
```bash
iwctl station wlan0 connect "$SSID" --passphrase="$PASSWORD"
```

**With:**
```bash
# Use a more secure approach - create temporary config file
cat > /tmp/wifi_config <<EOF
network={
    ssid="$SSID"
    psk="$PASSWORD"
}
EOF
iwctl station wlan0 connect "$SSID" --config-file=/tmp/wifi_config
rm -f /tmp/wifi_config
```

### Fix 2: Secure WiFi Connection in secondscript.sh

**File:** `secondscript.sh` (lines 17, 24)

**Replace:**
```bash
sudo nmcli device wifi connect "$SSID" password "$PASSWORD"
```

**With:**
```bash
# Use interactive password prompt
sudo nmcli device wifi connect "$SSID" --ask
```

### Fix 3: Replace Base64 Script with Documented Version

**File:** `secondscript.sh` (line 543)

**Replace:**
```bash
echo "IyEvYmluL2Jhc2gK..." | base64 -d | sudo tee /etc/libvirt/hooks/qemu
```

**With:**
```bash
# Install documented hugepage management hook
sudo cp /archinstall/SCRIPT/libvirt-hugepage-hook.sh /etc/libvirt/hooks/qemu
```

## 2. Error Handling Improvements

### Fix 4: Correct Exit Code Check in install.sh

**File:** `install.sh` (line 124)

**Replace:**
```bash
if [ "$?" -eq 0 ]; then
```

**With:**
```bash
if pacstrap /mnt base linux linux-headers linux-firmware; then
```

### Fix 5: Add Error Handling to ACPID Scripts

**Files:** `SCRIPT/ACPID/SCRIPT/a-plug.sh` and `SCRIPT/ACPID/SCRIPT/a-unplug.sh`

**Add at the beginning of both files:**
```bash
#!/bin/bash
#
# Power Management Script - [Plugged/Unplugged] State
# Purpose: Optimize system settings based on power adapter state
# Hardware: MSI laptop with MSI-EC module support
#
set -euo pipefail

# Function to safely write to sysfs
safe_write() {
    local file="$1"
    local value="$2"
    
    if [[ -w "$file" ]]; then
        echo "$value" | tee "$file" >/dev/null || {
            logger "Power script: Failed to write '$value' to '$file'"
            return 1
        }
    else
        logger "Power script: Cannot write to '$file' (not writable or doesn't exist)"
        return 1
    fi
}

# Check if MSI-EC is available
if [[ ! -d "/sys/devices/platform/msi-ec" ]]; then
    logger "Power script: MSI-EC module not available, skipping MSI-specific settings"
    exit 0
fi

# Verify user is logged in for display commands
current_user=$(last | grep -v reboot | head -1 | cut -f1 -d' ')
if [[ -z "$current_user" ]] || [[ "$current_user" == "wtmp" ]]; then
    logger "Power script: No user logged in, skipping display settings"
    USER_LOGGED_IN=false
else
    USER_LOGGED_IN=true
fi
```

**Then replace the raw echo commands with safe_write calls:**

For `a-plug.sh`:
```bash
# MSI-EC settings for plugged state
safe_write /sys/devices/platform/msi-ec/shift_mode turbo
safe_write /sys/devices/platform/msi-ec/fan_mode auto

# CPU performance settings
for cpu_gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    [[ -f "$cpu_gov" ]] && safe_write "$cpu_gov" performance
done

for cpu_pref in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
    [[ -f "$cpu_pref" ]] && safe_write "$cpu_pref" performance
done

for cpu_bias in /sys/devices/system/cpu/cpu*/power/energy_perf_bias; do
    [[ -f "$cpu_bias" ]] && safe_write "$cpu_bias" 0
done

# Display settings (only if user is logged in)
if [[ "$USER_LOGGED_IN" == "true" ]]; then
    runuser -l "$current_user" -c 'gnome-randr modify eDP-1 --mode 2560x1600@240.014' || \
        logger "Power script: Failed to set display mode"
    
    # Restore brightness if saved
    if [[ -f /tmp/brightness-saved ]]; then
        safe_write /sys/class/backlight/intel_backlight/brightness "$(cat /tmp/brightness-saved)"
    fi
fi

sleep 5

# Set power profile
if command -v powerprofilesctl >/dev/null 2>&1; then
    powerprofilesctl set performance || logger "Power script: Failed to set power profile"
fi
```

For `a-unplug.sh`:
```bash
# MSI-EC settings for unplugged state
safe_write /sys/devices/platform/msi-ec/shift_mode eco
safe_write /sys/devices/platform/msi-ec/fan_mode auto

# CPU power saving settings
for cpu_gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    [[ -f "$cpu_gov" ]] && safe_write "$cpu_gov" powersave
done

for cpu_pref in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
    [[ -f "$cpu_pref" ]] && safe_write "$cpu_pref" power
done

for cpu_bias in /sys/devices/system/cpu/cpu*/power/energy_perf_bias; do
    [[ -f "$cpu_bias" ]] && safe_write "$cpu_bias" 15
done

# Display settings (only if user is logged in)
if [[ "$USER_LOGGED_IN" == "true" ]]; then
    # Save current brightness
    if [[ -r /sys/class/backlight/intel_backlight/brightness ]]; then
        cat /sys/class/backlight/intel_backlight/brightness > /tmp/brightness-saved
    fi
    
    # Set power-saving display mode and brightness
    runuser -l "$current_user" -c 'gnome-randr modify eDP-1 --mode 2560x1600@60.008' || \
        logger "Power script: Failed to set display mode"
    
    safe_write /sys/class/backlight/intel_backlight/brightness 22000
fi

sleep 5

# Set power profile
if command -v powerprofilesctl >/dev/null 2>&1; then
    powerprofilesctl set power-saver || logger "Power script: Failed to set power profile"
fi
```

## 3. Input Validation Functions

### Add to the beginning of scripts that accept user input:

```bash
# Input validation functions
validate_hostname() {
    local hostname="$1"
    if [[ ! "$hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
        echo "Error: Invalid hostname. Must be 1-63 characters, alphanumeric and hyphens only." >&2
        return 1
    fi
}

validate_username() {
    local username="$1"
    if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
        echo "Error: Invalid username. Must start with letter/underscore, max 32 chars." >&2
        return 1
    fi
}

validate_ssid() {
    local ssid="$1"
    if [[ ${#ssid} -eq 0 || ${#ssid} -gt 32 ]]; then
        echo "Error: SSID must be 1-32 characters long." >&2
        return 1
    fi
}
```

## 4. Shellcheck Fixes

### Fix in mkinitcpio-editor.sh (line 14):

**Replace:**
```bash
echo "${line#MODULES=(}" | sed 's/)$//'
```

**With:**
```bash
line="${line#MODULES=(}"
echo "${line%)}"
```

### Remove unused variable in mkinitcpio-editor.sh (line 34):

**Remove:**
```bash
local added=()
```

## 5. Add Script Headers

### Standard header template for all scripts:

```bash
#!/bin/bash
#
# Script: [filename]
# Purpose: [Brief description of what the script does]
# Author: MaxenceTech
# Dependencies: [List key dependencies like internet, specific hardware, etc.]
# Usage: [How to run the script and any parameters]
# Hardware: [Any hardware-specific requirements]
# Last Modified: [Date]
#
set -euo pipefail

# Script configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $SCRIPT_NAME: $*" >&2
}

error() {
    log "ERROR: $*"
    exit 1
}
```

## 6. Download Verification Function

### Add to scripts that download files:

```bash
# Secure download function with hash verification
download_and_verify() {
    local url="$1"
    local output="$2"
    local expected_hash="$3"
    local max_retries=3
    local retry=0
    
    while [[ $retry -lt $max_retries ]]; do
        if wget --timeout=30 --tries=3 "$url" -O "$output"; then
            if echo "$expected_hash $output" | sha256sum -c --quiet; then
                log "Successfully downloaded and verified $output"
                return 0
            else
                log "Hash verification failed for $output (attempt $((retry + 1)))"
                rm -f "$output"
            fi
        else
            log "Download failed for $url (attempt $((retry + 1)))"
        fi
        ((retry++))
        sleep 2
    done
    
    error "Failed to download and verify $output after $max_retries attempts"
}
```

## Implementation Checklist

- [ ] Replace password command-line exposure in install.sh
- [ ] Replace password command-line exposure in secondscript.sh  
- [ ] Replace base64 script with documented version
- [ ] Fix exit code check in install.sh
- [ ] Add comprehensive error handling to ACPID scripts
- [ ] Add input validation functions to user input scripts
- [ ] Fix shellcheck warnings in mkinitcpio-editor.sh
- [ ] Add proper script headers to all files
- [ ] Implement secure download verification
- [ ] Test all changes in isolated environment

## Testing Protocol

1. **Test WiFi connection fixes** in VM without exposing real credentials
2. **Verify ACPID scripts** don't break on systems without MSI-EC
3. **Test libvirt hook** with VM creation/destruction
4. **Validate input validation** with various edge cases
5. **Run shellcheck** on all modified scripts
6. **Verify no functionality regression** in original use cases

This implementation guide provides specific, actionable fixes that address the major security and reliability issues identified in the audit while maintaining the scripts' functionality.