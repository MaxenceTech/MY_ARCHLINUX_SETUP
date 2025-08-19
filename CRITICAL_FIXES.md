# Critical Security Fixes and Immediate Improvements

## Priority 1: Security Vulnerabilities (Fix Immediately)

### 1. Password Exposure in Command Line
**Files:** `install.sh` (line 25), `secondscript.sh` (lines 17, 24)

**Current vulnerable code:**
```bash
iwctl station wlan0 connect "$SSID" --passphrase="$PASSWORD"
sudo nmcli device wifi connect "$SSID" password "$PASSWORD"
```

**Fixed code:**
```bash
# For iwctl - use environment variable
export WIFI_PASSWORD="$PASSWORD"
iwctl station wlan0 connect "$SSID" --passphrase-from-env

# For nmcli - use interactive mode
sudo nmcli device wifi connect "$SSID" --ask
```

### 2. Unverified Base64 Script Execution
**File:** `secondscript.sh` (line 543)

**Issue:** Executing base64-encoded script without documentation or verification

**Fix:** Decode and review the script, then include it as a separate documented file:
```bash
# Instead of base64 execution, create a separate file
sudo cp /archinstall/SCRIPT/libvirt-hugepage-hook.sh /etc/libvirt/hooks/qemu
sudo chmod +x /etc/libvirt/hooks/qemu
```

### 3. Download Integrity Verification
**File:** `secondscript.sh` (lines 225, 228, 512)

**Add hash verification:**
```bash
download_and_verify() {
    local url="$1"
    local output="$2"
    local expected_hash="$3"
    
    wget "$url" -O "$output"
    echo "$expected_hash $output" | sha256sum -c || {
        echo "Hash verification failed for $output"
        rm -f "$output"
        return 1
    }
}
```

## Priority 2: Error Handling Improvements

### 1. Add Error Handling to ACPID Scripts
**Files:** `SCRIPT/ACPID/SCRIPT/a-plug.sh`, `SCRIPT/ACPID/SCRIPT/a-unplug.sh`

**Add to beginning of both files:**
```bash
#!/bin/bash
set -euo pipefail

# Validate hardware presence
if [[ ! -d "/sys/devices/platform/msi-ec" ]]; then
    logger "MSI-EC not available, skipping MSI-specific settings"
    exit 0
fi

# Safe write function
safe_write() {
    local file="$1"
    local value="$2"
    if [[ -w "$file" ]]; then
        echo "$value" | tee "$file" || logger "Failed to write $value to $file"
    else
        logger "Cannot write to $file (not writable)"
    fi
}
```

### 2. Fix Shellcheck Issues
**File:** `install.sh` (line 124)
```bash
# Instead of:
if [ "$?" -eq 0 ]; then

# Use:
if pacstrap /mnt base linux linux-headers linux-firmware; then
```

**File:** `mkinitcpio-editor.sh` (line 14)
```bash
# Instead of sed, use parameter expansion:
extract_modules() {
    local line
    line=$(get_modules_line)
    line="${line#MODULES=(}"
    echo "${line%)}"
}
```

## Priority 3: Input Validation

### Add User Input Validation
**Files:** All scripts accepting user input

```bash
validate_hostname() {
    local hostname="$1"
    if [[ ! "$hostname" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,62}[a-zA-Z0-9]?$ ]]; then
        echo "Invalid hostname format" >&2
        return 1
    fi
}

validate_username() {
    local username="$1"
    if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        echo "Invalid username format" >&2
        return 1
    fi
}
```

## Priority 4: Documentation Headers

Add to all scripts:
```bash
#!/bin/bash
#
# Script Name: [filename]
# Purpose: [Brief description]
# Author: MaxenceTech  
# Dependencies: [List key dependencies]
# Usage: [How to run the script]
# Hardware: [Any hardware-specific requirements]
#
set -euo pipefail
```

## Quick Win Fixes (Low Effort, High Impact)

1. **Add script headers** to all files
2. **Remove unused variables** (shellcheck SC2034)
3. **Use parameter expansion** instead of sed where applicable
4. **Add file existence checks** before operations
5. **Group related package installations** to reduce redundancy

## Testing Recommendations

1. **Test password fixes** in isolated environment
2. **Verify ACPID scripts** don't break power management
3. **Validate download verification** doesn't break installations
4. **Test input validation** with various edge cases

## Implementation Order

1. Fix password exposure (highest security risk)
2. Add error handling to ACPID scripts (system stability)
3. Add input validation (prevents bad inputs)
4. Address shellcheck warnings (code quality)
5. Add documentation headers (maintainability)

This prioritized list focuses on the most critical security and reliability improvements that can be implemented quickly without breaking existing functionality.