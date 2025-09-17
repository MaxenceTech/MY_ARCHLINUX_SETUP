# MY_ARCHLINUX_SETUP

Ce dépôt contient des scripts automatisés pour gérer l'installation d'Arch Linux sur mon PC portable MSI A14VHG (Intel Core i7-14650HX, 2 SSD NVME (peut aussi gérer l'installation si un seul est detecté), 64GB de RAM, RTX 4080). La configuration est optimisée pour le gaming et l'utilisation de machines virtuelles, afin de tirer pleinement parti du matériel. Vous trouverez ici des outils adaptés à une installation efficace, ainsi que des ajustements spécifiques pour les performances graphiques et la virtualisation.

## Nouvelles fonctionnalités de sécurité

### 🔒 Chiffrement LUKS avec AES-NI
- **Chiffrement complet du disque** : Toutes les partitions (root, swap, data) sont chiffrées avec LUKS2
- **Optimisation AES-NI** : Détection automatique et utilisation de l'accélération matérielle AES-NI
- **Algorithmes optimisés** : 
  - Cipher: `aes-xts-plain64`
  - Hash: `sha512`
  - PBKDF: `argon2id`
  - Taille de clé: 512 bits

### 🛡️ Secure Boot avec systemd-ukify
- **Images kernel unifiées (UKI)** : Génération automatique avec systemd-ukify
- **Clés Secure Boot personnalisées** : Génération automatique des clés PK, KEK, et db
- **Signature automatique** : Tous les kernels sont automatiquement signés
- **Support multi-configuration** :
  - Configuration NVIDIA standard
  - Configuration GPU passthrough
  - Images de secours (fallback)

## Usage :
```
./install.sh
```
Puis après le redémarrage, 
```
cd /archinstall/SCRIPT
./secondscript.sh
```

## Configuration Secure Boot

Après l'installation, vous devez enroller les clés Secure Boot dans votre firmware UEFI :

### 1. Copier les clés sur USB
```bash
sudo ./SCRIPT/copy-secureboot-keys.sh
```

### 2. Enrollement dans le firmware UEFI
1. Redémarrez et entrez dans la configuration UEFI (F2, F12, ou DEL)
2. Naviguez vers Sécurité → Secure Boot
3. Activez le "Mode personnalisé" ou "Secure Boot avancé"
4. Effacez les clés existantes
5. Enrollez les clés dans cet ordre :
   - `db.crt` (Database Key)
   - `KEK.crt` (Key Exchange Key)  
   - `PK.crt` (Platform Key - **ACTIVE LE SECURE BOOT**)
6. Sauvegardez et quittez

⚠️ **Important** : L'enrollement de la Platform Key active immédiatement le Secure Boot. Gardez les clés en sécurité !

## Chiffrement des disques

Le script configure automatiquement :
- **Configuration 1 disque** : EFI (non chiffré) + Root (chiffré) + Swap (chiffré)
- **Configuration 2 disques** : 
  - Disque 1 : EFI (non chiffré) + Root (chiffré)
  - Disque 2 : Swap (chiffré) + Data (chiffré)

Au démarrage, vous devrez saisir les mots de passe de déchiffrement pour chaque partition LUKS.

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
