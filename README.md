# MY_ARCHLINUX_SETUP

Ce dépôt contient des scripts automatisés pour gérer l'installation d'Arch Linux sur mon PC portable MSI A14VHG (Intel Core i7-14650HX, 2 SSD NVME (peut aussi gérer l'installation si un seul est detecté), 64GB de RAM, RTX 4080). La configuration est optimisée pour le gaming et l'utilisation de machines virtuelles, afin de tirer pleinement parti du matériel. Vous trouverez ici des outils adaptés à une installation efficace, ainsi que des ajustements spécifiques pour les performances graphiques et la virtualisation.

## Usage :
```
./install.sh
```
Puis après le redémarrage, 
```
cd /archinstall/SCRIPT
./secure-boot.sh
```
Puis après le redémarrage, 
```
cd /archinstall/SCRIPT
./secondscript.sh
```

### Pour les images libvirt, voici ma recommandation en matière d'autorisation : 
```
sudo chown ${USER}:libvirt-qemu /var/lib/libvirt/images/*.qcow2
sudo chmod 600 /var/lib/libvirt/images/*.qcow2
```

### NVIDIA

Les sorties de la carte graphique NVIDIA seront désactivées afin de pouvoir laisser le HDMI dummy dessus.

# To-Do

- CPU Undervolt via intel-undervolt
- AppAmor config (optionnal)
