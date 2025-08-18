#!/bin/bash

# Exit on any error, undefined variables, and pipe failures
set -euo pipefail

moduleainsere=""
brutegrepmodule=$(grep -v  -n "^#" /etc/mkinitcpio.conf | grep "MODULES=")
textemodule="${brutegrepmodule#*:}"
lignemodule="${brutegrepmodule%:*}"

if [ ${#1} -gt 1 ]; then
    if [ "$1" = "-a" ] || [ "$1" = "--add" ]; then
        for param in "${@:2}"
        do
            moduleainsere+="$param "
        done
        if [ ${#textemodule} -gt 11 ]; then
            moduledebase="${textemodule:9:$((${#textemodule}-11))}"
        else
            moduledebase=" "
        fi
        sed -i "$((lignemodule)) d" /etc/mkinitcpio.conf 
        sed -i "$((lignemodule-1)) a MODULES=($moduledebase$moduleainsere)" /etc/mkinitcpio.conf 
        mkinitcpio -p linux
    elif [ "$1" = "-r" ] || [ "$1" = "--remove" ]; then
        for param in "${@:2}"
        do
            if grep -q "MODULES=(" /etc/mkinitcpio.conf && grep -q "$param" /etc/mkinitcpio.conf; then
                sed -i "s/[[:space:]]$param//g" /etc/mkinitcpio.conf
                mkinitcpio -p linux
                echo "$param supprimé de /etc/mkinitcpio.conf !"
            else
                echo "$param non trouvé dans /etc/mkinitcpio.conf !"
            fi
        done
    elif [ "$1" = "-p" ] || [ "$1" = "--print" ]; then
        if [ "${#textemodule}" -gt 11 ] && [ -n "${textemodule:9:$((${#textemodule}-11))// }" ]; then
            echo "Les modules installés sont : ${textemodule:9:$((${#textemodule}-11))}"
        else
            echo "Aucun module présent dans /etc/mkinitcpio.conf !"
        fi
    elif [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo -e "\n                                          ###############\n###########################################  Commandes  ############################################\n                                          ###############                                          #\n                                                                                                   #\n--print ou -p  : Affiche les modules présents dans /etc/mkinitcpio.conf.                           #\n--add ou -a    : Ajoute un ou des modules dans /etc/mkinitcpio.conf et applique la modification.   #\n--remove ou -r : Supprime un ou des modules dans /etc/mkinitcpio.conf et applique la modification. #\n                                                                                                   #\n####################################################################################################\n"
    else
        echo -e "Paramètre non valide !\n--help ou -h pour voir toutes les commandes !"
    fi
else
echo "Aucun paramètre !"
fi
