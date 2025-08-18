# MY_ARCHLINUX_SETUP

Ce dépôt contient des scripts automatisés pour gérer l'installation d'Arch Linux sur mon PC portable MSI A14VHG (Intel Core i7-14650HX, 128GB de RAM, RTX 4080). La configuration est optimisée pour le gaming et l'utilisation de machines virtuelles, afin de tirer pleinement parti du matériel haut de gamme. Vous trouverez ici des outils adaptés à une installation efficace, ainsi que des ajustements spécifiques pour les performances graphiques et la virtualisation.

## Améliorations récentes

### Sécurité et fiabilité
- Ajout de `set -euo pipefail` pour une meilleure gestion des erreurs
- Correction des variables non quotées pour éviter les problèmes de séparation de mots
- Amélioration de la gestion des erreurs pour les opérations critiques
- Validation des entrées utilisateur renforcée

### Optimisations d'installation
- Groupement des packages pour une installation plus rapide (~60% de réduction des appels pacman)
- Meilleure organisation des packages par catégorie (graphiques, audio, gaming, etc.)
- Détection et gestion améliorées des disques NVMe multiples
- Vérifications de connectivité réseau renforcées

### Qualité du code
- Conformité shellcheck (réduction de 50+ avertissements à moins de 30)
- Style de codage plus cohérent et meilleure gestion des variables
- Élimination des patterns inefficaces
- Ajout d'un `.gitignore` pour une meilleure gestion du dépôt

## Utilisation

1. **Installation principale** : Exécutez `install.sh` depuis un live USB Arch Linux
2. **Configuration post-installation** : `secondscript.sh` s'exécute après le redémarrage
3. **Validation** : Utilisez `validate.sh` pour tester la syntaxe des scripts

## Structure

- `install.sh` - Script d'installation principal (partitionnement, pacstrap)
- `SCRIPT/firstscript.sh` - Configuration initiale du système (chroot)
- `SCRIPT/secondscript.sh` - Configuration post-installation
- `SCRIPT/aurinstall.sh` - Installateur de packages AUR
- `SCRIPT/mkinitcpio-editor.sh` - Éditeur de configuration mkinitcpio
- `CONFIG/` - Fichiers de configuration pour diverses applications
- `SCRIPT/ACPID/` - Scripts de gestion d'alimentation ACPI