#!/bin/bash

#==============================================================================
# ACPI Event Handler
#==============================================================================
# Description: Main ACPI event handler that routes power events to appropriate
#              scripts based on adapter connection status
# Usage: Called automatically by acpid daemon
# Events: Handles AC adapter connect/disconnect events
#==============================================================================

case "$1" in
    ac_adapter)
        case "$2" in
            ACPI0003:00)
                case "$4" in
                    00000000)
                        # AC adapter disconnected - switch to power saving mode
                        /etc/acpi/SCRIPT/a-unplug.sh
                        ;;
                    00000001)
                        # AC adapter connected - switch to performance mode
                        /etc/acpi/SCRIPT/a-plug.sh
                        ;;
                esac
                ;;
            *)
                logger "ACPI action undefined: $2"
                ;;
        esac
        ;;
    *)
        logger "ACPI group/action undefined: $1 / $2"
        ;;
esac

# vim:set ts=4 sw=4 ft=sh et:
