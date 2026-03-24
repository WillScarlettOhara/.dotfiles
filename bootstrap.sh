#!/bin/bash
# bootstrap.sh — Installation "Zero-Touch" from scratch

set -e
export NODE_NO_WARNINGS=1

echo "======================================"
echo "🚀 SUPER BOOTSTRAP (Zero-Touch Provisioning)"
echo "======================================"

# ─── 1. Dépendances minimales ───────────────────────────────────────────────
echo ""
echo "📦 Installation des dépendances système..."
sudo pacman -S --noconfirm jq stow git openssh sshfs unzip wget rclone base-devel 2>/dev/null || true

# ─── 2. Bitwarden CLI ───────────────────────────────────────────────────────
if ! command -v bw &>/dev/null; then
  echo "🔐 Installation Bitwarden CLI..."
  BW_VERSION="2026.2.0"
  wget -q "https://github.com/bitwarden/clients/releases/download/cli-v${BW_VERSION}/bw-linux-${BW_VERSION}.zip" -O /tmp/bw.zip
  unzip -q /tmp/bw.zip -d /tmp/bw
  sudo install -m 755 /tmp/bw/bw /usr/local/bin/bw
  rm -rf /tmp/bw.zip /tmp/bw
fi

# ─── 3. Login + unlock Bitwarden ────────────────────────────────────────────
echo ""
echo "🔑 Connexion à Bitwarden..."
BW_STATUS=$(bw status | jq -r '.status' 2>/dev/null || echo "error")
if [[ "$BW_STATUS" == "unauthenticated" ]]; then
  bw login
fi

echo -n "🔓 Vault verrouillé. Entrez votre mot de passe maître : "
read -s -r BW_PASS </dev/tty
echo ""
export BW_PASS
export BW_SESSION=$(bw unlock --raw --passwordenv BW_PASS)
unset BW_PASS

if [[ -z "$BW_SESSION" ]]; then
  echo "❌ Échec du déverrouillage."
  exit 1
fi
bw sync &>/dev/null

# ─── 4. Récupération des clés SSH depuis Bitwarden ──────────────────────────
echo ""
echo "🗝️  Récupération des clés SSH..."
mkdir -p ~/.ssh && chmod 700 ~/.ssh
bw get item "SSH GitHub" | jq -r '.sshKey.privateKey // empty' >~/.ssh/id_rsa
bw get item "SSH GitHub" | jq -r '.sshKey.publicKey // empty' >~/.ssh/id_rsa.pub
chmod 600 ~/.ssh/id_rsa && chmod 644 ~/.ssh/id_rsa.pub

ssh-keyscan github.com >>~/.ssh/known_hosts 2>/dev/null
ssh-keyscan REDACTED >>~/.ssh/known_hosts 2>/dev/null
ssh-keyscan REDACTED >>~/.ssh/known_hosts 2>/dev/null
chmod 644 ~/.ssh/known_hosts

# ─── 5. Clone des dotfiles ──────────────────────────────────────────────────
echo ""
echo "📂 Clone des dotfiles..."
if [[ ! -d "$HOME/.dotfiles" ]]; then
  git clone git@github.com:WillScarlettOhara/.dotfiles.git "$HOME/.dotfiles"
fi

# ─── 6. Application des dotfiles via stow ───────────────────────────────────
echo "🔗 Application des dotfiles via stow..."
cd "$HOME/.dotfiles"
stow --adopt zsh tmux git nvim kitty mpv lsd 2>/dev/null || stow zsh tmux git nvim kitty mpv lsd

# ─── 7. Installation des paquets (Optionnel mais recommandé) ────────────────
echo ""
echo "📦 Installation de tous les paquets du système (pkglist.txt)..."
if command -v paru &>/dev/null && [[ -f "$HOME/.dotfiles/pkglist.txt" ]]; then
  paru -S --needed --noconfirm - <"$HOME/.dotfiles/pkglist.txt"
else
  echo "  ⚠️  Paru non installé ou pkglist.txt introuvable. Ignoré."
fi

# ─── 8. Récupération des Secrets Système (Rclone, Samba, fstab) ─────────────
echo ""
echo "🔐 Récupération des secrets système depuis Bitwarden..."
# Rclone
mkdir -p ~/.config/rclone
bw get item "Config Rclone" | jq -r '.notes // empty' >~/.config/rclone/rclone.conf

# Samba Credentials
sudo bash -c "bw get item 'Samba Credentials' | jq -r '.notes // empty' > /etc/samba/.credentials"
sudo chmod 600 /etc/samba/.credentials

# Fstab (Affiche pour info, mais demande validation avant d'écrire car dangereux)
echo "  📝 Lignes Fstab récupérées :"
bw get item "Fstab Mounts" | jq -r '.notes // empty' | sudo tee /tmp/fstab_append.txt >/dev/null
cat /tmp/fstab_append.txt
echo "  (Ces lignes ont été sauvegardées dans /tmp/fstab_append.txt. À ajouter manuellement plus tard par sécurité)."

# Verrouillage BW car on n'en a plus besoin
bw lock &>/dev/null

# ─── 9. Montage Automatique de OneDrive ─────────────────────────────────────
echo ""
echo "☁️  Démarrage du service Rclone OneDrive..."
systemctl --user daemon-reload
systemctl --user enable --now rclone-onedrive.service

echo "  ⏳ Attente de la connexion à OneDrive..."
BACKUP_DIR="$HOME/OneDrive/Linux_Backup_2026"
while [ ! -d "$BACKUP_DIR" ]; do
  sleep 2
  echo -n "."
done
echo " ✅ OneDrive connecté !"

# ─── 10. Restauration OneDrive (App Configs & Scripts) ──────────────────────
echo ""
echo "🔄 Restauration des configurations depuis OneDrive..."
RSYNC_CMD=(rsync -auL --info=progress2)

"${RSYNC_CMD[@]}" "$BACKUP_DIR/Configs_App/" ~/.config/
mkdir -p ~/.local/bin ~/.local/share/applications
"${RSYNC_CMD[@]}" "$BACKUP_DIR/Scripts_et_Raccourcis/bin/" ~/.local/bin/
"${RSYNC_CMD[@]}" "$BACKUP_DIR/Scripts_et_Raccourcis/applications/" ~/.local/share/applications/
chmod +x ~/.local/bin/*

# ─── 11. Restauration Bluetooth (Souris) ────────────────────────────────────
echo ""
echo "🖱️  Restauration des clés Bluetooth..."
sudo "${RSYNC_CMD[@]}" "$BACKUP_DIR/Secrets/bluetooth/" /var/lib/bluetooth/
sudo systemctl restart bluetooth
echo "  ✅ Bluetooth redémarré (votre souris devrait fonctionner)"

# ─── 12. Restauration des Profils Lourds (Firefox, Thunderbird, etc) ────────
echo ""
echo "🦊 Restauration de Firefox & Thunderbird..."
mkdir -p ~/.config/mozilla/firefox ~/.thunderbird
"${RSYNC_CMD[@]}" "$BACKUP_DIR/Profils_Lourds/firefox/" ~/.config/mozilla/firefox/
"${RSYNC_CMD[@]}" "$BACKUP_DIR/Profils_Lourds/thunderbird/" ~/.thunderbird/
"${RSYNC_CMD[@]}" "$BACKUP_DIR/Profils_Lourds/libreoffice/" ~/.config/libreoffice/ 2>/dev/null || true
"${RSYNC_CMD[@]}" "$BACKUP_DIR/Profils_Lourds/calibre/" ~/.config/calibre/ 2>/dev/null || true

# ─── 13. Restauration Mounts SSHFS & Services Systemd ───────────────────────
echo ""
echo "🖥️  Restauration des Services Systemd & Mounts..."
"${RSYNC_CMD[@]}" "$BACKUP_DIR/Services_Systemd/User/" ~/.config/systemd/user/
sudo "${RSYNC_CMD[@]}" "$BACKUP_DIR/Services_Systemd/System/"*.mount /etc/systemd/system/ 2>/dev/null || true

sudo mkdir -p /mnt/calibreweb /mnt/torrent /mnt/1TB /mnt/2TB /mnt/samba/data
sudo chown "$USER:$USER" /mnt/calibreweb /mnt/torrent

sudo systemctl daemon-reload
# sudo systemctl enable --now mnt-calibreweb.mount mnt-torrent.mount

# ─── 14. Restauration de la VM Windows 11 ───────────────────────────────────
echo ""
echo "🪟 Restauration de la Machine Virtuelle (qcow2)..."
export NOM_VM="win11"
if [[ -f "$BACKUP_DIR/Machines_Virtuelles/${NOM_VM}.qcow2" ]]; then
  sudo cp "$BACKUP_DIR/Machines_Virtuelles/${NOM_VM}.qcow2" /var/lib/libvirt/images/
  sudo chown root:root "/var/lib/libvirt/images/${NOM_VM}.qcow2"
  sudo chmod 644 "/var/lib/libvirt/images/${NOM_VM}.qcow2"
  sudo virsh define "$BACKUP_DIR/Machines_Virtuelles/${NOM_VM}.xml"
  echo "  ✅ VM définie dans KVM"
else
  echo "  ⚠️  VM introuvable dans la sauvegarde."
fi

echo ""
echo "========================================================="
echo "🎉 RESTAURATION TOTALE TERMINÉE AVEC SUCCÈS !"
echo "========================================================="
echo "Dernières actions manuelles :"
echo "1. Ajoutez le contenu de /tmp/fstab_append.txt à votre /etc/fstab (sudo nvim /etc/fstab)"
echo "2. Lancez 'source ~/.zshrc'"

