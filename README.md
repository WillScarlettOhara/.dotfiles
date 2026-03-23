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
export BW_SESSION=$(bw unlock --raw)
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
rsync -auv "$BACKUP_DIR/Profils_Lourds/.mozilla" ~/
rsync -auv "$BACKUP_DIR/Profils_Lourds/.thunderbird" ~/
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

```bash
mkdir -p ~/.config/systemd/user/
rsync -auv "$BACKUP_DIR/Services_Systemd/User/" ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now rclone-onedrive.service
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
7. Restaurer les services Systemd
8. Restaurer les profils lourds
9. Restaurer Sigil
10. Restaurer la VM
11. Installer les packages : `paru -S - < ~/.dotfiles/pkglist.txt`
