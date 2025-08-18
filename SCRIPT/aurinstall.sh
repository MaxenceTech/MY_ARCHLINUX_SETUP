#!/bin/bash

# Exit on any error, undefined variables, and pipe failures
set -euo pipefail

package=""
parametre=""

for param in "$@"
do
    if [ "${param:0:1}" != "-" ]; then
        package+="$param "
    else
        parametre+="$param "
    fi
done

mkdir -p /tmp/aur-stockage

for param in $package
do
    cd /tmp/aur-stockage || exit 1
    git clone "https://aur.archlinux.org/$param.git"
    cd "$param" || exit 1
    if LANG=c makepkg -si $parametre; then
        cd .. || exit 1
        rm -rf "$param"
    fi
done

cd ~ || exit 1
