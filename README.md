# 🔄 Guide de Restauration (Linux Backup 2026)

Ce guide explique comment restaurer les fichiers sauvegardés sur OneDrive vers une nouvelle installation Linux.

> **⚠️ Prérequis :**
> - Assurez-vous que OneDrive est synchronisé ou monté (ex: via Rclone) au chemin `$HOME/OneDrive/`.
> - Fermez les applications concernées (Firefox, Thunderbird, Neovim, etc.) avant de restaurer leurs configurations.
> - La commande `rsync` est recommandée pour restaurer en toute sécurité.

Définissez d'abord la variable de votre dossier de sauvegarde dans votre terminal :

```bash
BACKUP_DIR="$HOME/OneDrive/Linux_Backup_2026"
```

---

## 0. 🚀 Bootstrap automatique (méthode recommandée)

Le script `bootstrap.sh` automatise les étapes 1 à 3 en une seule commande.
Il récupère les clés SSH depuis Bitwarden, clone les dotfiles GitHub et applique stow.
Il configure également les known_hosts pour GitHub et les serveurs locaux (REDACTED, REDACTED).

```bash
bash bootstrap.sh
```

### Prérequis — Stocker les clés SSH dans Bitwarden

**À faire une seule fois sur la machine actuelle**, via l'interface web [vault.bitwarden.com](https://vault.bitwarden.com) :

1. Créer un **Nouvel élément** → type **Note sécurisée**
2. Nom : `SSH GitHub`
3. Dans **Notes**, coller le résultat de :
```bash
cat ~/.ssh/id_rsa | base64 -w 0
```
4. Ajouter un **Champ personnalisé** nommé `PUBLIC_KEY` avec le résultat de :
```bash
cat ~/.ssh/id_rsa.pub
```

---

## 1. 🔐 Récupération des clés SSH

### Méthode A — Via Bitwarden CLI (automatique)

```bash
# Installer le CLI si nécessaire (binaire officiel, Node.js intégré)
BW_VERSION="2026.2.0"
wget -q "https://github.com/bitwarden/clients/releases/download/cli-v${BW_VERSION}/bw-linux-${BW_VERSION}.zip" -O /tmp/bw.zip
unzip -q /tmp/bw.zip -d /tmp/bw
sudo install -m 755 /tmp/bw/bw /usr/local/bin/bw
rm -rf /tmp/bw.zip /tmp/bw

echo -n "Mot de passe maître : " && read -s BW_PASS && echo ""
export BW_PASS
export BW_SESSION=$(bw unlock --raw --passwordenv BW_PASS)
unset BW_PASS
bw sync

# Clé privée (stockée en base64 dans les notes)
bw get item "SSH GitHub" | jq -r '.notes' | base64 -d > ~/.ssh/id_rsa

# Clé publique (stockée dans le champ PUBLIC_KEY)
bw get item "SSH GitHub" | jq -r '.fields[] | select(.name == "PUBLIC_KEY") | .value' > ~/.ssh/id_rsa.pub

chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub

bw lock
```

### Méthode B — Via l'interface web Bitwarden (si CLI ne fonctionne pas)

1. Aller sur [vault.bitwarden.com](https://vault.bitwarden.com) depuis un navigateur
2. Se connecter et ouvrir l'item **SSH GitHub**
3. Copier le contenu du champ **Notes** (la clé privée encodée en base64)
4. Dans le terminal, coller le contenu base64 et décoder :

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Ouvrir un éditeur, coller le base64 copié depuis Bitwarden, sauvegarder
nvim /tmp/ssh_key_b64.txt

# Décoder et placer la clé
base64 -d /tmp/ssh_key_b64.txt > ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa

# Supprimer le fichier temporaire
rm /tmp/ssh_key_b64.txt
```

5. Copier la clé publique depuis le champ **PUBLIC_KEY** dans Bitwarden :

```bash
nvim ~/.ssh/id_rsa.pub
# Coller la clé publique, sauvegarder
chmod 644 ~/.ssh/id_rsa.pub
```

### Méthode C — Via OneDrive (si Bitwarden inaccessible)

> Nécessite que rclone soit configuré et OneDrive monté.

```bash
# Monter OneDrive manuellement si pas encore fait
rclone mount OneDrive: ~/OneDrive --vfs-cache-mode full &
sleep 5

rsync -auv "$BACKUP_DIR/Secrets/.ssh/" ~/.ssh/
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
```

### Vérification de la connexion GitHub

```bash
ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
ssh -T git@github.com
# Attendu : "Hi WillScarlettOhara! You've successfully authenticated"
```

---

## 2. 🐙 Dotfiles via GitHub

```bash
# Installer stow
sudo pacman -S stow  # ou apt install stow

# Cloner le repo
git clone git@github.com:WillScarlettOhara/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles

# Appliquer tous les dotfiles via symlinks
stow zsh tmux git nvim kitty mpv lsd
```

> **Note :** Si des fichiers existent déjà à la destination, stow refusera.

```bash
# En cas de conflit, forcer l'adoption des fichiers existants
stow --adopt zsh tmux git nvim kitty mpv lsd
```

---

## 3. 📄 Dotfiles (depuis OneDrive, si GitHub non disponible)

```bash
rsync -auv "$BACKUP_DIR/Dotfiles/" ~/
source ~/.zshrc
```

---

## 4. ⚙️ Configurations des Applications (Neovim, Kitty, etc.)

```bash
rsync -auv "$BACKUP_DIR/Configs_App/" ~/.config/
```

---

## 5. 🔧 Scripts et Raccourcis

```bash
mkdir -p ~/.local/bin ~/.local/share/applications
rsync -auv "$BACKUP_DIR/Scripts_et_Raccourcis/bin/" ~/.local/bin/
rsync -auv "$BACKUP_DIR/Scripts_et_Raccourcis/applications/" ~/.local/share/applications/
chmod +x ~/.local/bin/*
```

---

## 6. 🦊 Profils Lourds (Firefox, Thunderbird, LibreOffice, Calibre)

> **Attention :** Ne lancez pas Firefox ni Thunderbird pendant cette opération.

```bash
# Firefox
mkdir -p ~/.config/mozilla/firefox
rsync -auv "$BACKUP_DIR/Profils_Lourds/firefox/profiles.ini" ~/.config/mozilla/firefox/
rsync -auv "$BACKUP_DIR/Profils_Lourds/firefox/installs.ini" ~/.config/mozilla/firefox/
rsync -auv "$BACKUP_DIR/Profils_Lourds/firefox/d91w3rmx.default-release-1739246972176" ~/.config/mozilla/firefox/

# Thunderbird
mkdir -p ~/.thunderbird
rsync -auv "$BACKUP_DIR/Profils_Lourds/thunderbird/profiles.ini" ~/.thunderbird/
rsync -auv "$BACKUP_DIR/Profils_Lourds/thunderbird/o2dmdq0v.default-release" ~/.thunderbird/

# LibreOffice et Calibre
rsync -auv "$BACKUP_DIR/Profils_Lourds/libreoffice" ~/.config/
rsync -auv "$BACKUP_DIR/Profils_Lourds/calibre" ~/.config/
```

---

## 7. 🔑 Rclone

```bash
mkdir -p ~/.config/rclone
cp "$BACKUP_DIR/Secrets/rclone.conf" ~/.config/rclone/
```

---

## 8. 🖱️ Bluetooth (appairage souris dual-boot Windows/Linux)

```bash
sudo rsync -auv "$BACKUP_DIR/Secrets/bluetooth/" /var/lib/bluetooth/
sudo systemctl restart bluetooth
```

> Après restauration, la souris se reconnectera automatiquement sans ré-appairage.
> Si elle ne se reconnecte pas, redémarrez le service bluetooth et attendez quelques secondes.

---

## 9. 🔄 Services Systemd

### Utilisateur (rclone, etc.)

```bash
mkdir -p ~/.config/systemd/user/
rsync -auv "$BACKUP_DIR/Services_Systemd/User/" ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now rclone-onedrive.service
```

### Système — fstab (disques NTFS 1TB/2TB + Samba)

```bash
# Créer les points de montage
sudo mkdir -p /mnt/1TB /mnt/2TB /mnt/samba/data

# Restaurer le fstab
sudo cp "$BACKUP_DIR/Services_Systemd/fstab" /etc/fstab

# Restaurer les credentials Samba
sudo mkdir -p /etc/samba
sudo cp "$BACKUP_DIR/Secrets/.credentials" /etc/samba/.credentials
sudo chmod 600 /etc/samba/.credentials

# Recharger et monter
sudo systemctl daemon-reload
sudo mount /mnt/1TB
sudo mount /mnt/2TB
sudo mount /mnt/samba/data
```

### Système — mounts SSHFS (calibreweb, torrent)

```bash
# Installer sshfs
sudo pacman -S sshfs  # ou apt install sshfs

# Créer les points de montage
sudo mkdir -p /mnt/calibreweb /mnt/torrent
sudo chown wills:wills /mnt/calibreweb /mnt/torrent

# Restaurer les unit files
sudo cp "$BACKUP_DIR/Services_Systemd/System/"*.mount /etc/systemd/system/

# Copier la clé SSH pour root (nécessaire pour les mounts au boot)
sudo mkdir -p /root/.ssh
sudo ssh-keyscan REDACTED | sudo tee -a /root/.ssh/known_hosts
sudo ssh-keyscan REDACTED | sudo tee -a /root/.ssh/known_hosts

# Activer et démarrer
sudo systemctl daemon-reload
sudo systemctl enable --now mnt-calibreweb.mount
sudo systemctl enable --now mnt-torrent.mount

# Vérifier
systemctl status mnt-calibreweb.mount mnt-torrent.mount
```

---

## 10. ⌨️ GJS OSK (Clavier Virtuel GNOME)

```bash
mkdir -p ~/.local/share/gnome-shell/extensions/
rsync -auv --exclude="gjsosk_settings.ini" "$BACKUP_DIR/GJS_OSK/" ~/.local/share/gnome-shell/extensions/
dconf load /org/gnome/shell/extensions/gjsosk/ < "$BACKUP_DIR/GJS_OSK/gjsosk_settings.ini"
```

---

## 11. 📖 Sigil (Éditeur EPUB)

```bash
rsync -auv "$BACKUP_DIR/Sigil/config/sigil-ebook" ~/.config/
rsync -auv "$BACKUP_DIR/Sigil/share/sigil-ebook" ~/.local/share/
```

---

## 12. 🖥️ Machines Virtuelles (KVM / QEMU)

```bash
export NOM_VM="win11"

sudo cp "$BACKUP_DIR/Machines_Virtuelles/${NOM_VM}.qcow2" /var/lib/libvirt/images/
sudo chown root:root "/var/lib/libvirt/images/${NOM_VM}.qcow2"
sudo chmod 644 "/var/lib/libvirt/images/${NOM_VM}.qcow2"
sudo virsh define "$BACKUP_DIR/Machines_Virtuelles/${NOM_VM}.xml"
sudo virsh list --all
```

---

## 💡 Ordre recommandé pour une nouvelle installation

1. Récupérer les clés SSH (Bitwarden web → méthode B si CLI KO)
2. Vérifier la connexion GitHub : `ssh -T git@github.com`
3. Lancer `bootstrap.sh` ou cloner les dotfiles manuellement + stow
4. Monter OneDrive : `systemctl --user start rclone-onedrive.service`
5. Restaurer Rclone config
6. Restaurer Bluetooth
7. Restaurer les services Systemd utilisateur
8. Restaurer fstab (1TB, 2TB, Samba) + credentials Samba
9. Restaurer les mounts SSHFS (calibreweb, torrent)
10. Restaurer les profils lourds
11. Restaurer Sigil
12. Restaurer la VM
13. Installer les packages : `paru -S - < ~/.dotfiles/pkglist.txt`