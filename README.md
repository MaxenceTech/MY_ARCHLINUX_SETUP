# MY_ARCHLINUX_SETUP

Ce dépôt contient des scripts automatisés pour gérer l'installation d'Arch Linux sur mon PC portable MSI A14VHG (Intel Core i7-14650HX, 2 SSD NVME (peut aussi gérer l'installation si un seul est detecté), 64GB de RAM, RTX 4080). La configuration est optimisée pour le gaming et l'utilisation de machines virtuelles, afin de tirer pleinement parti du matériel. Vous trouverez ici des outils adaptés à une installation efficace, ainsi que des ajustements spécifiques pour les performances graphiques et la virtualisation.

## Usage :
```
./install.sh
```
Puis après le redémarrage, 
```
cd /archinstall/SCRIPT
./secondscript.sh
```

## NB :
### Informations sur gamemode
Gamemode utilisera libstrangle pour limiter le FPS à 72 lorsque certains écrans (projecteur LG ou téléviseur Samsung) sont détectés ou lorsque l'appareil fonctionne sur batterie. Pour contourner cette limite, utilisez STRANGLE_FPS=0 et/ou STRANGLE_FPS_BATTERY=0 après gamemoderun

### Pour les images libvirt, voici ma recommandation en matière d'autorisation : 
```
sudo chown ${USER}:libvirt-qemu /var/lib/libvirt/images/*.qcow2
sudo chmod 600 /var/lib/libvirt/images/*.qcow2
```

### NVIDIA

Les sorties de la carte graphique NVIDIA seront désactivées afin de pouvoir laisser le HDMI dummy dessus.
