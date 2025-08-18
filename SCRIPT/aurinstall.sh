#!/bin/bash
for param in "$@"
    do
        if [ $(echo $param | cut -c 1) != "-" ]; then
            package+="$param "
        else :
            parametre+="$param "
        fi
    done
mkdir /tmp/aur-stockage

for param in ${package[@]}
    do
        cd /tmp/aur-stockage
        git clone https://aur.archlinux.org/$param.git
        cd $param
        if [ "$?" = "0" ]; then
            LANG=c makepkg -si $parametre
            if [ "$?" = "0" ]; then
                cd ..
                rm -rf $param
            fi
        fi
    done

cd ~
