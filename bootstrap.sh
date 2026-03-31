#!/bin/bash
# bootstrap.sh — Installation "Zero-Touch" from scratch

set -e
export NODE_NO_WARNINGS=1

echo "======================================"
echo "🚀 SUPER BOOTSTRAP (Zero-Touch Provisioning)"
echo "======================================"

# ─── 0. Détection DE (GNOME) ────────────────────────────────────────────────
IS_GNOME=false
if [[ "${XDG_CURRENT_DESKTOP^^}" == *"GNOME"* ]]; then
  IS_GNOME=true
  echo "🖥️  Environnement GNOME détecté."
fi

# ─── 1. Installation des Paquets ────────────────────────────────────────────
echo ""
echo "📦 Installation des paquets du système..."

PACKAGES=(
  base-devel jq stow git openssh sshfs unzip wget rclone restic curl tar gzip zoxide wl-clipboard ttf-jetbrains-mono-nerd extension-manager
  nodejs npm python jre-openjdk rust luarocks
  tmux ghostty lazygit ripgrep lsd zsh-theme-powerlevel10k
  neovim mpv firefox thunderbird libreoffice-fresh sigil sunshine
  xkb-qwerty-fr
  qemu-full libvirt virt-manager dnsmasq edk2-ovmf swtpm bridge-utils iptables-nft
)

if [ "$IS_GNOME" = true ]; then
  PACKAGES+=(
    gnome-shell-extension-dash-to-panel
    gnome-shell-extension-arc-menu
    gnome-shell-extension-vitals
  )
fi

if command -v paru &>/dev/null; then
  paru -Syu --noconfirm
  paru -S --needed --noconfirm "${PACKAGES[@]}"
else
  sudo pacman -Syu --noconfirm
  sudo pacman -S --needed --noconfirm "${PACKAGES[@]}"
fi

sudo -v && wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | sudo sh /dev/stdin

echo "⌨️  Configuration automatique du clavier..."
if [ "$IS_GNOME" = true ]; then
  echo "  🖥️  GNOME détecté : Application de gsettings pour qwerty-fr..."
  gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us+qwerty-fr')]" 2>/dev/null || true
else
  echo "  🐧 Autre DE détecté : Application via localectl..."
  sudo localectl set-x11-keymap us pc105 qwerty-fr 2>/dev/null || true
fi

# ─── 2. Configuration du Pare-feu (Sunshine) ────────────────────────────────
echo ""
echo "🔥 Configuration du pare-feu pour Sunshine..."
if command -v firewall-cmd &>/dev/null; then
  sudo firewall-cmd --permanent --add-port={47984,47989,47990,48010}/tcp >/dev/null
  sudo firewall-cmd --permanent --add-port={47998,47999,48000}/udp >/dev/null
  sudo firewall-cmd --reload >/dev/null
  echo "  ✅ Ports Firewalld ouverts"
elif command -v ufw &>/dev/null; then
  sudo ufw allow 47984,47989,47990,48010/tcp >/dev/null
  sudo ufw allow 47998,47999,48000/udp >/dev/null
  echo "  ✅ Ports UFW ouverts"
else
  echo "  ⚠️  Aucun pare-feu détecté (ufw / firewalld). Ignoré."
fi

# ─── 3. Bitwarden CLI ───────────────────────────────────────────────────────
install_bitwarden_cli() {
  echo "🔄 Vérification de Bitwarden CLI..."
  local current_version="0.0.0"
  local latest_version

  latest_version=$(curl -s "https://api.github.com/repos/bitwarden/clients/releases" |
    jq -r '[.[] | select(.name | contains("CLI"))][0].tag_name' | sed 's/cli-v//' || echo "")

  if command -v bw &>/dev/null; then
    current_version=$(NODE_NO_WARNINGS=1 bw --version 2>/dev/null || echo "0.0.0")

    if [ "$current_version" = "$latest_version" ] && [ "$current_version" != "0.0.0" ]; then
      echo "  ✅ Bitwarden CLI est à jour ($current_version)"
      return
    fi
  fi

  echo "  ⬇️ Téléchargement de Bitwarden CLI v$latest_version..."
  sudo rm -f /usr/local/bin/bw 2>/dev/null || true
  wget -q "https://vault.bitwarden.com/download/?app=cli&platform=linux" -O /tmp/bw.zip
  unzip -q -o /tmp/bw.zip -d /tmp/bw_extract
  sudo install -m 755 /tmp/bw_extract/bw /usr/local/bin/bw
  rm -rf /tmp/bw.zip /tmp/bw_extract
  echo "  ✅ Bitwarden CLI installé."
}
install_bitwarden_cli

# ─── 4. Login + unlock Bitwarden ────────────────────────────────────────────
echo ""
echo "🔑 Connexion à Bitwarden..."
BW_STATUS=$(bw status | jq -r '.status' 2>/dev/null || echo "error")
if [ "$BW_STATUS" = "unauthenticated" ]; then
  bw login </dev/tty
fi

echo -n "🔓 Vault verrouillé. Entrez votre mot de passe maître : "
read -s -r BW_PASS </dev/tty
echo ""

export BW_PASS
BW_SESSION=$(bw unlock --raw --passwordenv BW_PASS)
export BW_SESSION
unset BW_PASS

if [ -z "$BW_SESSION" ]; then
  echo "❌ Échec du déverrouillage."
  exit 1
fi
bw sync &>/dev/null

# ─── 5. Récupération des clés SSH depuis Bitwarden ──────────────────────────
echo ""
echo "🗝️  Récupération des clés SSH..."
mkdir -p ~/.ssh && chmod 700 ~/.ssh

# Recherche sûre : On isole l'objet JSON complet correspondant exactement au nom
BW_SSH_JSON=$(bw list items --search "SSH GitHub" 2>/dev/null | jq -r '.[] | select(.name == "SSH GitHub")')
echo "$BW_SSH_JSON" | jq -r '.sshKey.privateKey // empty' >~/.ssh/id_rsa
echo "$BW_SSH_JSON" | jq -r '.sshKey.publicKey // empty' >~/.ssh/id_rsa.pub
chmod 600 ~/.ssh/id_rsa && chmod 644 ~/.ssh/id_rsa.pub

{
  ssh-keyscan github.com
  ssh-keyscan REDACTED
  ssh-keyscan REDACTED
} >>~/.ssh/known_hosts 2>/dev/null
chmod 644 ~/.ssh/known_hosts

sudo mkdir -p /root/.ssh
sudo sh -c "{
  ssh-keyscan REDACTED
  ssh-keyscan REDACTED
} >> /root/.ssh/known_hosts 2>/dev/null"

# ─── 6. Clone des dotfiles & Extensions GNOME ───────────────────────────────
echo ""
echo "📂 Clone des dotfiles depuis GitHub..."
if [ ! -d "$HOME/.dotfiles" ]; then
  git clone git@github.com:WillScarlettOhara/.dotfiles.git "$HOME/.dotfiles"
fi

if [ "$IS_GNOME" = true ]; then
  echo "⌨️  Installation de gjs-osk (Clavier visuel) pour GNOME..."
  GJS_OSK_URL=$(curl -s https://api.github.com/repos/Vishram1123/gjs-osk/releases/latest | jq -r '.assets[] | select(.name == "gjsosk@vishram1123_main.zip") | .browser_download_url')
  if [ -n "$GJS_OSK_URL" ] && [ "$GJS_OSK_URL" != "null" ]; then
    wget -q "$GJS_OSK_URL" -O /tmp/gjsosk.zip
    gnome-extensions install --force /tmp/gjsosk.zip || true
    rm -f /tmp/gjsosk.zip
    echo "  ✅ gjs-osk installé (nécessitera le relog pour s'activer)."
  else
    echo "  ⚠️ Impossible de trouver la dernière release de gjs-osk."
  fi
fi

# ─── 7. Application des dotfiles via stow ───────────────────────────────────
echo ""
echo "🔗 Application des dotfiles via stow..."
cd "$HOME/.dotfiles"
STOW_FOLDERS=(zsh tmux git nvim ghostty mpv lsd local-bin local-apps systemd-user)
stow --adopt "${STOW_FOLDERS[@]}" 2>/dev/null || stow "${STOW_FOLDERS[@]}"
echo "  ✅ Dotfiles et scripts appliqués !"

# ─── 8. Restauration des configurations système (Depuis Git) ────────────────
echo ""
echo "⚙️  Restauration système (Gnome & Mounts)..."
sudo cp "$HOME/.dotfiles/system-mounts/"*.mount /etc/systemd/system/ 2>/dev/null || true
sudo systemctl daemon-reload

if [ "$IS_GNOME" = true ]; then
  dconf load /org/gnome/shell/extensions/gjsosk/ <"$HOME/.dotfiles/gnome/gjsosk_settings.ini" 2>/dev/null || true
  dconf load /org/gnome/shell/extensions/dash-to-panel/ <"$HOME/.dotfiles/gnome/dash-to-panel_settings.ini" 2>/dev/null || true
  dconf load /org/gnome/shell/extensions/arcmenu/ <"$HOME/.dotfiles/gnome/arcmenu_settings.ini" 2>/dev/null || true
  dconf load /org/gnome/shell/extensions/vitals/ <"$HOME/.dotfiles/gnome/vitals_settings.ini" 2>/dev/null || true
  echo "  ✅ Paramètres des extensions GNOME restaurés."
fi

# ─── 9. Récupération des Secrets Système (Bitwarden) ────────────────────────
echo ""
echo "🔐 Récupération des secrets système depuis Bitwarden..."

export RESTIC_PASSWORD
RESTIC_PASSWORD=$(bw list items --search "Restic Password" 2>/dev/null | jq -r '.[] | select(.name == "Restic Password") | .notes // empty')

mkdir -p ~/.config/rclone
bw list items --search "Config Rclone" 2>/dev/null | jq -r '.[] | select(.name == "Config Rclone") | .notes // empty' >~/.config/rclone/rclone.conf

sudo mkdir -p /etc/samba
sudo --preserve-env=BW_SESSION bash -c "bw list items --search 'Samba Credentials' 2>/dev/null | jq -r '.[] | select(.name == \"Samba Credentials\") | .notes // empty' > /etc/samba/.credentials"
sudo chmod 600 /etc/samba/.credentials

echo "  📝 Lignes Fstab récupérées :"
bw list items --search "Fstab Mounts" 2>/dev/null | jq -r '.[] | select(.name == "Fstab Mounts") | .notes // empty' | sudo tee /tmp/fstab_append.txt >/dev/null
cat /tmp/fstab_append.txt

bw lock &>/dev/null

# ─── 10. Montage Automatique de OneDrive ────────────────────────────────────
echo ""
echo "☁️  Démarrage de Rclone OneDrive..."
systemctl --user daemon-reload
systemctl --user enable --now rclone-onedrive.service

echo "  ⏳ Attente de la connexion à OneDrive..."
BACKUP_DIR="$HOME/OneDrive/Backup_PC"

while [ ! -d "$BACKUP_DIR" ]; do
  sleep 2
  echo -n "."
done
echo " ✅ OneDrive connecté !"

# ─── 11. Restauration ultra-rapide avec Restic ──────────────────────────────
echo ""
echo "🔄 Restauration des profils lourds via Restic..."

export RESTIC_REPOSITORY="$BACKUP_DIR/restic-repo"

if [ -z "$RESTIC_PASSWORD" ]; then
  echo "❌ Erreur : Mot de passe Restic introuvable dans Bitwarden."
else
  echo "  ⏳ Restauration des applications et navigateurs..."
  restic restore latest --target / \
    --include "$HOME/.config/sunshine" \
    --include "$HOME/.config/mozilla/firefox" \
    --include "$HOME/.thunderbird" \
    --include "$HOME/.config/libreoffice" \
    --include "$HOME/.config/calibre" \
    --include "$HOME/.local/share/sigil-ebook" 2>/dev/null || echo "⚠️  Certains fichiers utilisateurs n'ont pas pu être restaurés."

  echo "  ⏳ Restauration des clés Bluetooth et de la VM..."
  export NOM_VM="win11"
  sudo --preserve-env=RESTIC_REPOSITORY,RESTIC_PASSWORD restic restore latest --target / \
    --include "/var/lib/bluetooth" \
    --include "/var/lib/libvirt/images/${NOM_VM}.qcow2" \
    --include "/etc/libvirt/qemu/${NOM_VM}.xml" 2>/dev/null || echo "⚠️  Certains fichiers systèmes n'ont pas pu être restaurés."

  sudo systemctl restart bluetooth
  echo "  ✅ Restauration Restic terminée !"
fi

# ─── 12. Préparation des Mounts & VM ────────────────────────────────────────
echo ""
echo "🖥️  Préparation de l'Hyperviseur et des Mounts..."
sudo mkdir -p /mnt/calibreweb /mnt/torrent /mnt/1TB /mnt/2TB /mnt/samba/data
sudo chown "$USER:$USER" /mnt/calibreweb /mnt/torrent

sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt,kvm "$USER"

if [ -f "/etc/libvirt/qemu/${NOM_VM}.xml" ]; then
  echo "🪟 Enregistrement de la Machine Virtuelle Windows 11 dans KVM..."
  sudo chown root:root "/var/lib/libvirt/images/${NOM_VM}.qcow2" 2>/dev/null || true
  sudo chmod 644 "/var/lib/libvirt/images/${NOM_VM}.qcow2" 2>/dev/null || true
  sudo virsh define "/etc/libvirt/qemu/${NOM_VM}.xml" 2>/dev/null || true
  echo "  ✅ VM définie avec succès."
fi

# ─── 13. Shell par défaut ───────────────────────────────────────────────────
echo ""
echo "🐚 Configuration de zsh comme shell par défaut..."
ZSH_PATH=$(which zsh)
grep -qxF "$ZSH_PATH" /etc/shells || echo "$ZSH_PATH" | sudo tee -a /etc/shells
chsh -s "$ZSH_PATH"

echo ""
echo "========================================================="
echo "🎉 RESTAURATION TOTALE TERMINÉE AVEC SUCCÈS !"
echo "========================================================="
echo "Dernières actions manuelles :"
echo "1. Ajoutez le contenu de /tmp/fstab_append.txt à votre /etc/fstab (sudo nvim /etc/fstab)"
echo "2. Déconnectez puis reconnectez votre session utilisateur (Requis pour libvirt, clavier et extensions)"
echo "3. Une fois reconnecté, exécutez le script './post_relog.sh' pour activer vos extensions GNOME."
