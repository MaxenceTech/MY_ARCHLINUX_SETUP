#!/bin/bash

#==============================================================================
# System Compatibility Checker
#==============================================================================
# Description: Check system compatibility for Secure Boot and LUKS encryption
# Author: MaxenceTech
# Usage: Run this script to verify system requirements
#==============================================================================

set -euo pipefail

echo "=============================================================================="
echo "System Compatibility Checker for Secure Boot + LUKS"
echo "=============================================================================="
echo ""

# Check if running in UEFI mode
echo "🔍 Checking boot mode..."
if [ -d /sys/firmware/efi ]; then
    echo "  ✓ System is booted in UEFI mode"
    UEFI_MODE=true
else
    echo "  ❌ System is NOT booted in UEFI mode"
    echo "     Secure Boot requires UEFI firmware"
    UEFI_MODE=false
fi

# Check for AES-NI support
echo ""
echo "🔍 Checking AES-NI hardware acceleration..."
if grep -q aes /proc/cpuinfo; then
    echo "  ✓ AES-NI hardware acceleration is supported"
    AES_NI=true
else
    echo "  ❌ AES-NI hardware acceleration not detected"
    echo "     LUKS encryption will work but with reduced performance"
    AES_NI=false
fi

# Check CPU features
echo ""
echo "🔍 Checking CPU security features..."
cpu_flags=$(grep "^flags" /proc/cpuinfo | head -1 | cut -d: -f2)

if echo "$cpu_flags" | grep -q "aes"; then
    echo "  ✓ AES instruction set supported"
fi

if echo "$cpu_flags" | grep -q "avx"; then
    echo "  ✓ AVX instruction set supported"
fi

if echo "$cpu_flags" | grep -q "avx2"; then
    echo "  ✓ AVX2 instruction set supported"
fi

# Check for required tools
echo ""
echo "🔍 Checking required tools availability..."

required_tools=("cryptsetup" "openssl" "efibootmgr")
missing_tools=()

for tool in "${required_tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "  ✓ $tool is available"
    else
        echo "  ❌ $tool is missing"
        missing_tools+=("$tool")
    fi
done

# Check if systemd-ukify is available (might not be on live environment)
if command -v ukify >/dev/null 2>&1; then
    echo "  ✓ systemd-ukify is available"
else
    echo "  ⚠️  systemd-ukify not found (will be installed during setup)"
fi

# Check storage devices
echo ""
echo "🔍 Checking storage devices..."
echo "Available NVMe devices:"
nvme_devices=($(ls /dev/nvme*n1 2>/dev/null || true))
if [ ${#nvme_devices[@]} -eq 0 ]; then
    echo "  ❌ No NVMe devices found"
    echo "     This script is designed for NVMe storage"
else
    for device in "${nvme_devices[@]}"; do
        size=$(lsblk -d -n -o SIZE "$device" 2>/dev/null || echo "unknown")
        model=$(lsblk -d -n -o MODEL "$device" 2>/dev/null || echo "unknown")
        echo "  ✓ $device - $size ($model)"
    done
fi

# Check available memory
echo ""
echo "🔍 Checking system memory..."
total_mem=$(grep MemTotal /proc/meminfo | awk '{print $2}')
total_mem_gb=$((total_mem / 1024 / 1024))

if [ "$total_mem_gb" -ge 8 ]; then
    echo "  ✓ Sufficient memory: ${total_mem_gb}GB"
else
    echo "  ⚠️  Limited memory: ${total_mem_gb}GB"
    echo "     Argon2id PBKDF may be slow with less than 8GB RAM"
fi

# Final compatibility assessment
echo ""
echo "=============================================================================="
echo "COMPATIBILITY SUMMARY"
echo "=============================================================================="

compatible=true

if [ "$UEFI_MODE" = false ]; then
    echo "❌ CRITICAL: System must be booted in UEFI mode for Secure Boot"
    compatible=false
fi

if [ ${#nvme_devices[@]} -eq 0 ]; then
    echo "❌ CRITICAL: No NVMe devices found"
    compatible=false
fi

if [ ${#missing_tools[@]} -gt 0 ]; then
    echo "⚠️  WARNING: Missing tools will be installed during setup"
fi

if [ "$AES_NI" = false ]; then
    echo "⚠️  WARNING: No AES-NI support - encryption will be slower"
fi

if [ "$compatible" = true ]; then
    echo ""
    echo "✅ SYSTEM IS COMPATIBLE"
    echo "   Your system supports both Secure Boot and LUKS encryption"
    echo "   You can proceed with the installation script"
else
    echo ""
    echo "❌ SYSTEM IS NOT COMPATIBLE"
    echo "   Please address the critical issues before running the installation"
fi

echo ""
echo "For optimal performance, ensure:"
echo "• UEFI Secure Boot is disabled in firmware (will be reconfigured)"
echo "• All important data is backed up (installation will erase disks)"
echo "• System has stable power supply during installation"
echo ""
echo "=============================================================================="