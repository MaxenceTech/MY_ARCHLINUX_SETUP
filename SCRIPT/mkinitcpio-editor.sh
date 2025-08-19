#!/bin/bash
set -euo pipefail

MKINITCONF="/etc/mkinitcpio.conf"

get_modules_line() {
    grep -v "^#" "$MKINITCONF" | grep "^MODULES="
}

extract_modules() {
    local line
    line=$(get_modules_line)
    # Remove 'MODULES=(' and trailing ')'
    echo "${line#MODULES=(}" | sed 's/)$//'
}

update_modules() {
    local new_modules="$1"
    # Remove the old MODULES= line, add new one where it was
    local lineno
    lineno=$(grep -n "^MODULES=" "$MKINITCONF" | cut -d: -f1)
    if [[ -z "$lineno" ]]; then
        # If not present, append at end
        echo "MODULES=($new_modules)" >> "$MKINITCONF"
    else
        sed -i "${lineno}d" "$MKINITCONF"
        sed -i "$((lineno-1))a MODULES=($new_modules)" "$MKINITCONF"
    fi
}

add_modules() {
    local current
    current=$(extract_modules)
    local added=()
    local word
    # Build an array for current modules
    read -ra arr <<<"$current"
    for word in "${@:2}"; do
        if [[ ! " ${arr[*]} " =~ " $word " ]]; then
            arr+=("$word")
        fi
    done
    update_modules "${arr[*]}"
    mkinitcpio -p linux
    echo "Modules added successfully!"
}

remove_modules() {
    local current
    current=$(extract_modules)
    local to_remove=("${@:2}")
    local filtered=()
    local word
    read -ra arr <<<"$current"
    for word in "${arr[@]}"; do
        skip=
        for r in "${to_remove[@]}"; do
            if [[ "$word" == "$r" ]]; then
                skip=1
                break
            fi
        done
        if [[ -z "$skip" ]]; then
            filtered+=("$word")
        fi
    done
    update_modules "${filtered[*]}"
    mkinitcpio -p linux
    echo "Modules removed successfully!"
}

print_modules() {
    local current
    current=$(extract_modules)
    if [[ -n "$current" && "$current" != " " ]]; then
        echo "Les modules installés sont : $current"
    else
        echo "Aucun module présent dans /etc/mkinitcpio.conf !"
    fi
}

show_help() {
    cat <<EOF

############### Commandes disponibles ###############

  -p, --print     : Affiche les modules présents dans /etc/mkinitcpio.conf.
  -a, --add       : Ajoute un ou des modules, ex : $0 -a kvm vfio.
  -r, --remove    : Supprime un ou des modules, ex : $0 -r kvm vfio.
  -h, --help      : Affiche cette aide.

#####################################################

EOF
}

main() {
    if [[ $# -lt 1 ]]; then
        show_help
        exit 1
    fi
    case "$1" in
        -a|--add)
            if [[ $# -lt 2 ]]; then
                echo "Spécifiez au moins un module à ajouter."
                exit 1
            fi
            add_modules "$@"
            ;;
        -r|--remove)
            if [[ $# -lt 2 ]]; then
                echo "Spécifiez au moins un module à supprimer."
                exit 1
            fi
            remove_modules "$@"
            ;;
        -p|--print)
            print_modules
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Commande inconnue : $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
