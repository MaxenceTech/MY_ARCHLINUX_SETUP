#!/bin/bash
#
# LibVirt Hugepage Management Hook
# Purpose: Automatically allocate/deallocate hugepages for VMs with "thp" in the name
# Author: MaxenceTech
# Usage: Called automatically by libvirt when VMs start/stop
# Dependencies: libvirt, hugepages support in kernel
#
# This script is installed as /etc/libvirt/hooks/qemu
# It allocates hugepages based on VM memory requirements for better performance
#
set -euo pipefail

guest_name="$1"
libvirt_task="$2"
libvirt_subtask="$3"

# Log function for debugging
log_message() {
    logger "LibVirt Hugepage Hook: $*"
}

# Only process VMs with "thp" (Transparent Huge Pages) in their name
if [[ $guest_name == *"thp"* ]]; then
    log_message "Processing VM: $guest_name, Task: $libvirt_task, Subtask: $libvirt_subtask"
    
    if [ "$libvirt_task" == "prepare" ] && [ "$libvirt_subtask" == "begin" ]; then
        # Extract memory amount from VM name (assumes format like "vm-thp-8192")
        MEMORY=$(echo "$guest_name" | tac -s'-' | head -1)
        
        # Calculate required hugepages based on system hugepage size
        HUGEPAGE_SIZE_KB=$(grep Hugepagesize /proc/meminfo | awk '{print $2}')
        HUGEPAGE_SIZE_MB=$((HUGEPAGE_SIZE_KB / 1024))
        HUGEPAGES=$((MEMORY / HUGEPAGE_SIZE_MB))
        
        log_message "Allocating $HUGEPAGES hugepages for ${MEMORY}MB VM"
        
        # Attempt to allocate hugepages
        echo "$HUGEPAGES" > /proc/sys/vm/nr_hugepages
        ALLOC_PAGES=$(cat /proc/sys/vm/nr_hugepages)
        
        TRIES=0
        MAX_TRIES=1000
        
        # Retry allocation with memory compaction if needed
        while (( ALLOC_PAGES != HUGEPAGES && TRIES < MAX_TRIES )); do
            # Trigger memory compaction to defragment RAM
            echo 1 > /proc/sys/vm/compact_memory
            echo "$HUGEPAGES" > /proc/sys/vm/nr_hugepages
            ALLOC_PAGES=$(cat /proc/sys/vm/nr_hugepages)
            
            log_message "Successfully allocated $ALLOC_PAGES / $HUGEPAGES hugepages (attempt $((TRIES + 1)))"
            ((TRIES++))
        done
        
        # Check if allocation was successful
        if [ "$ALLOC_PAGES" -ne "$HUGEPAGES" ]; then
            log_message "ERROR: Unable to allocate all hugepages after $TRIES attempts. Reverting..."
            echo 0 > /proc/sys/vm/nr_hugepages
            exit 1
        fi
        
        log_message "Successfully allocated $HUGEPAGES hugepages for VM $guest_name"
        
    elif [ "$libvirt_task" == "release" ] && [ "$libvirt_subtask" == "end" ]; then
        # Release hugepages when VM stops
        log_message "Releasing hugepages for VM: $guest_name"
        echo 0 > /proc/sys/vm/nr_hugepages
        log_message "Hugepages released for VM $guest_name"
    fi
fi