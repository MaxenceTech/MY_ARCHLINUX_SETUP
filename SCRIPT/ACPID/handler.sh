#!/bin/bash
# Default acpi script that takes an entry for all actions

case "$1" in
    ac_adapter)
        case "$2" in
            ACPI0003:00)
                case "$4" in
                    00000000)
                        /etc/acpi/SCRIPT/a-unplug.sh
                        ;;
                    00000001)
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
