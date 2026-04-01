#!/bin/bash
# bootstrap.sh — Installation "Zero-Touch" from scratch
# Usage : curl -fsSL https://raw.githubusercontent.com/WillScarlettOhara/.dotfiles/master/bootstrap.sh | bash

set -e
export NODE_NO_WARNINGS=1

echo "======================================"
echo "🚀 SUPER BOOTSTRAP (Zero-Touch Provisioning)"
echo "======================================"

# ─── 0. Détection DE ────────────────────────────────────────────────────────
IS_GNOME=false
if [[ "${XDG_CURRENT_DESKTOP^^}" == *"GNOME"* ]]; then
  IS_GNOME=true
  echo "🖥️  Environnement GNOME détecté."
fi

# ─── 1. Installation des Paquets ────────────────────────────────────────────
echo ""
echo "📦 Installation des paquets du système..."

PACKAGES=(
  base-devel jq stow git openssh sshfs unzip wget rclone restic curl tar gzip
  zoxide wl-clipboard ttf-jetbrains-mono-nerd
  nodejs npm python python-pip jre-openjdk rust luarocks
  tmux ghostty lazygit ripgrep lsd zsh-theme-powerlevel10k
  neovim mpv firefox thunderbird libreoffice-fresh sigil sunshine
  discord element-desktop
  xkb-qwerty-fr
  qemu-full libvirt virt-manager dnsmasq edk2-ovmf swtpm bridge-utils iptables-nft
)

if [ "$IS_GNOME" = true ]; then
  PACKAGES+=(
    gnome-shell-extension-dash-to-panel
    gnome-shell-extension-arc-menu
    gnome-shell-extension-vitals
    gnome-shell-extension-appindicator
    gnome-shell-extension-copyous
    extension-manager
  )
fi

if command -v paru &>/dev/null; then
  paru -Syu --noconfirm
  paru -S --needed --noconfirm "${PACKAGES[@]}"
else
  sudo pacman -Syu --noconfirm
  sudo pacman -S --needed --noconfirm "${PACKAGES[@]}"
fi

# Calibre (installateur officiel, version toujours à jour)
sudo -v && wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | sudo sh /dev/stdin

# FUSE (requis par rclone mount)
sudo modprobe fuse
grep -qxF "user_allow_other" /etc/fuse.conf || echo "user_allow_other" | sudo tee -a /etc/fuse.conf
echo "fuse" | sudo tee /etc/modules-load.d/fuse.conf >/dev/null

# ─── 2. Configuration du clavier ────────────────────────────────────────────
echo ""
echo "⌨️  Configuration du clavier..."
if [ "$IS_GNOME" = true ]; then
  gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us+qwerty-fr')]" 2>/dev/null || true
else
  sudo localectl set-x11-keymap us pc105 qwerty-fr 2>/dev/null || true
fi

# Police monospace GNOME
if [ "$IS_GNOME" = true ]; then
  gsettings set org.gnome.desktop.interface monospace-font-name "JetBrainsMono Nerd Font 11" 2>/dev/null || true
fi
fc-cache -fq

# ─── 3. Pare-feu Sunshine ───────────────────────────────────────────────────
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
  echo "  ⚠️  Aucun pare-feu détecté. Ignoré."
fi

# ─── 4. Bitwarden CLI ───────────────────────────────────────────────────────
echo ""
echo "🔄 Vérification de Bitwarden CLI..."
install_bitwarden_cli() {
  local latest_version
  latest_version=$(curl -s "https://api.github.com/repos/bitwarden/clients/releases" |
    jq -r '[.[] | select(.name | contains("CLI"))][0].tag_name' | sed 's/cli-v//' || echo "")

  if command -v bw &>/dev/null; then
    local current_version
    current_version=$(NODE_NO_WARNINGS=1 bw --version 2>/dev/null || echo "0.0.0")
    if [ "$current_version" = "$latest_version" ] && [ "$current_version" != "0.0.0" ]; then
      echo "  ✅ Bitwarden CLI à jour ($current_version)"
      return
    fi
  fi

  echo "  ⬇️  Téléchargement Bitwarden CLI v$latest_version..."
  sudo rm -f /usr/local/bin/bw 2>/dev/null || true
  wget -q "https://vault.bitwarden.com/download/?app=cli&platform=linux" -O /tmp/bw.zip
  unzip -q -o /tmp/bw.zip -d /tmp/bw_extract
  sudo install -m 755 /tmp/bw_extract/bw /usr/local/bin/bw
  rm -rf /tmp/bw.zip /tmp/bw_extract
  echo "  ✅ Bitwarden CLI installé."
}
install_bitwarden_cli

# ─── 5. Login + unlock Bitwarden ────────────────────────────────────────────
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

# ─── 6. Clés SSH depuis Bitwarden ───────────────────────────────────────────
echo ""
echo "🗝️  Récupération des clés SSH..."
mkdir -p ~/.ssh && chmod 700 ~/.ssh

BW_SSH_JSON=$(bw list items --search "SSH GitHub" 2>/dev/null |
  jq -r '.[] | select(.name == "SSH GitHub")')
echo "$BW_SSH_JSON" | jq -r '.sshKey.privateKey // empty' >~/.ssh/id_rsa
echo "$BW_SSH_JSON" | jq -r '.sshKey.publicKey  // empty' >~/.ssh/id_rsa.pub
chmod 600 ~/.ssh/id_rsa && chmod 644 ~/.ssh/id_rsa.pub

# Uniquement GitHub — les IPs locales seront restaurées via restic (known_hosts)
ssh-keyscan github.com >>~/.ssh/known_hosts 2>/dev/null
chmod 644 ~/.ssh/known_hosts

# ─── 7. Clone des dotfiles ──────────────────────────────────────────────────
echo ""
echo "📂 Clone des dotfiles depuis GitHub..."
if [ ! -d "$HOME/.dotfiles" ]; then
  git clone git@github.com:WillScarlettOhara/.dotfiles.git "$HOME/.dotfiles"
fi

# ─── 8. gjs-osk (clavier visuel GNOME) ─────────────────────────────────────
if [ "$IS_GNOME" = true ]; then
  echo ""
  echo "⌨️  Installation de gjs-osk..."
  GJS_OSK_URL=$(curl -s https://api.github.com/repos/Vishram1123/gjs-osk/releases/latest |
    jq -r '.assets[] | select(.name == "gjsosk@vishram1123_main.zip") | .browser_download_url')
  if [ -n "$GJS_OSK_URL" ] && [ "$GJS_OSK_URL" != "null" ]; then
    wget -q "$GJS_OSK_URL" -O /tmp/gjsosk.zip
    gnome-extensions install --force /tmp/gjsosk.zip || true
    rm -f /tmp/gjsosk.zip
    sudo pacman -S --needed --noconfirm python-xkbcommon
    mkdir -p ~/.cache/gjs-osk/keycodes
    # genKeyMap.py est dans les dotfiles
    python "$HOME/.dotfiles/genKeyMap.py" us+qwerty-fr \
      >~/.cache/gjs-osk/keycodes/us+qwerty-fr.json
    echo "  ✅ gjs-osk installé."
  else
    echo "  ⚠️  Release gjs-osk introuvable."
  fi
fi

# ─── 9. Stow des dotfiles ───────────────────────────────────────────────────
echo ""
echo "🔗 Application des dotfiles via stow..."

# Nettoie les éventuels dotfiles-ssh qui entreraient en conflit
if [ -d "$HOME/.dotfiles-ssh" ]; then
  cd "$HOME/.dotfiles-ssh"
  stow --delete --target="$HOME" . 2>/dev/null || true
fi

cd "$HOME/.dotfiles"
STOW_FOLDERS=(zsh tmux git nvim ghostty mpv lsd local-bin local-apps systemd-user)
stow "${STOW_FOLDERS[@]}"
echo "  ✅ Dotfiles appliqués !"

# ─── 10. Restauration système depuis Git ────────────────────────────────────
echo ""
echo "⚙️  Restauration des configs système..."
sudo cp "$HOME/.dotfiles/system-mounts/"*.mount /etc/systemd/system/ 2>/dev/null || true
sudo systemctl daemon-reload

if [ "$IS_GNOME" = true ]; then
  dconf load /org/gnome/shell/extensions/gjsosk/ \
    <"$HOME/.dotfiles/gnome/gjsosk_settings.ini" 2>/dev/null || true
  dconf load /org/gnome/shell/extensions/dash-to-panel/ \
    <"$HOME/.dotfiles/gnome/dash-to-panel_settings.ini" 2>/dev/null || true
  dconf load /org/gnome/shell/extensions/arcmenu/ \
    <"$HOME/.dotfiles/gnome/arcmenu_settings.ini" 2>/dev/null || true
  dconf load /org/gnome/shell/extensions/vitals/ \
    <"$HOME/.dotfiles/gnome/vitals_settings.ini" 2>/dev/null || true
  echo "  ✅ Extensions GNOME configurées."
fi

# ─── 11. Secrets depuis Bitwarden (rclone + restic uniquement) ──────────────
echo ""
echo "🔐 Récupération des secrets Bitwarden..."

export RESTIC_PASSWORD
RESTIC_PASSWORD=$(bw list items --search "Restic Password" 2>/dev/null |
  jq -r '.[] | select(.name == "Restic Password") | (.notes // .login.password // empty)')

if [ -z "$RESTIC_PASSWORD" ]; then
  echo "❌ Mot de passe Restic introuvable dans Bitwarden. Abandon."
  exit 1
fi

mkdir -p ~/.config/rclone
bw list items --search "Config Rclone" 2>/dev/null |
  jq -r '.[] | select(.name == "Config Rclone") | .notes // empty' \
    >~/.config/rclone/rclone.conf
echo "  ✅ rclone.conf récupéré."

bw lock &>/dev/null
echo "  🔒 Vault reverrouillé."

# ─── 12. Montage OneDrive ───────────────────────────────────────────────────
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

# ─── 13. Restauration Restic ────────────────────────────────────────────────
echo ""
echo "🔄 Restauration via Restic..."
export RESTIC_REPOSITORY="$BACKUP_DIR/restic-repo"

if ! restic snapshots &>/dev/null; then
  echo "⚠️  Aucun snapshot Restic trouvé. Première installation — restauration ignorée."
else
  echo "  ⏳ Restauration des profils utilisateurs..."
  restic restore latest --target / \
    --include "$HOME/.config/sunshine" \
    --include "$HOME/.config/mozilla/firefox" \
    --include "$HOME/.thunderbird" \
    --include "$HOME/.config/libreoffice" \
    --include "$HOME/.config/calibre" \
    --include "$HOME/.config/lg-buddy" \
    --include "$HOME/.local/share/sigil-ebook" \
    --include "$HOME/.ssh/known_hosts" \
    2>/dev/null || echo "  ⚠️  Certains profils n'ont pas pu être restaurés."

  echo "  ⏳ Restauration des configs système..."
  sudo --preserve-env=RESTIC_REPOSITORY,RESTIC_PASSWORD restic restore latest \
    --target / \
    --include "/var/lib/bluetooth" \
    --include "/etc/samba" \
    --include "/etc/fstab" \
    --include "/var/lib/libvirt/images/win11.qcow2" \
    --include "/etc/libvirt/qemu/win11.xml" \
    2>/dev/null || echo "  ⚠️  Certains fichiers système n'ont pas pu être restaurés."

  sudo systemctl restart bluetooth 2>/dev/null || true
  echo "  ✅ Restauration Restic terminée !"
fi

# ─── 14. Hyperviseur & Mounts ───────────────────────────────────────────────
echo ""
echo "🖥️  Préparation de l'hyperviseur et des mounts..."

sudo mkdir -p /mnt/calibreweb /mnt/torrent /mnt/2TB /mnt/samba/data
sudo chown "$USER:$USER" /mnt/calibreweb /mnt/torrent
sudo mkdir -p /etc/samba

# ISO VirtIO
VIRTIO_ISO="/var/lib/libvirt/images/virtio-win.iso"
if [ ! -f "$VIRTIO_ISO" ]; then
  echo "  💿 Téléchargement ISO VirtIO..."
  sudo wget -q \
    https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso \
    -O "$VIRTIO_ISO"
  sudo chmod 644 "$VIRTIO_ISO"
fi

# Mounts systemd
sudo systemctl daemon-reload
for mnt in mnt-calibreweb.mount mnt-torrent.mount; do
  if [ -f "/etc/systemd/system/$mnt" ]; then
    sudo systemctl enable --now "$mnt" 2>/dev/null || true
  fi
done

# Libvirt
sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt,kvm "$USER"
if [ -f "/etc/libvirt/qemu/win11.xml" ]; then
  sudo chown root:root "/var/lib/libvirt/images/win11.qcow2" 2>/dev/null || true
  sudo virsh define "/etc/libvirt/qemu/win11.xml" 2>/dev/null || true
  echo "  ✅ VM Windows 11 enregistrée."
fi

# fstab
if [ -f /etc/fstab ] && grep -q "ntfs3\|cifs" /etc/fstab 2>/dev/null; then
  echo "  ✅ /etc/fstab restauré par restic."
  sudo mount -a 2>/dev/null || echo "  ⚠️  Certains mounts ont échoué (normal si réseau indisponible)."
else
  echo "  ⚠️  /etc/fstab vide — à remplir manuellement après première sauvegarde."
fi

# ─── 15. LG Buddy ───────────────────────────────────────────────────────────
if [ "$IS_GNOME" = true ]; then
  echo ""
  echo "📺 Installation de LG Buddy..."
  sudo pacman -S --needed --noconfirm wakeonlan zenity

  git clone git@github.com:Faceless3882/LG_Buddy.git /tmp/LG_Buddy 2>/dev/null ||
    git -C /tmp/LG_Buddy pull --ff-only
  chmod +x /tmp/LG_Buddy/install.sh /tmp/LG_Buddy/configure.sh

  if [ -f "$HOME/.config/lg-buddy/config.env" ]; then
    echo "  ✅ Config LG Buddy trouvée (restic) — installation silencieuse..."
    cat >/tmp/LG_Buddy/configure.sh <<'STUB'
#!/bin/bash
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/bin/LG_Buddy_Common"
CONFIG_FILE="$(lg_buddy_user_config_path)"
echo "  → Configuration chargée depuis $CONFIG_FILE"
if [ -f "$HOME/.config/systemd/user/LG_Buddy_screen.service" ]; then
  systemctl --user daemon-reload
  systemctl --user restart LG_Buddy_screen.service 2>/dev/null || true
fi
STUB
    chmod +x /tmp/LG_Buddy/configure.sh
    printf 'Y\nN\n' | /tmp/LG_Buddy/install.sh
  else
    echo "  ⚠️  Aucune config LG Buddy — installation interactive..."
    /tmp/LG_Buddy/install.sh
  fi
  echo "  ✅ LG Buddy installé."
fi

# ─── 16. Shell par défaut ───────────────────────────────────────────────────
echo ""
echo "🐚 Configuration de zsh comme shell par défaut..."
ZSH_PATH=$(which zsh)
grep -qxF "$ZSH_PATH" /etc/shells || echo "$ZSH_PATH" | sudo tee -a /etc/shells
sudo usermod -s "$ZSH_PATH" "$USER"
echo "  ✅ Shell → zsh (effectif à la prochaine session)"

echo ""
echo "========================================================="
echo "🎉 RESTAURATION TOTALE TERMINÉE !"
echo "========================================================="
echo ""
echo "Actions manuelles restantes :"
echo "  1. Déconnectez/reconnectez votre session (libvirt, GNOME, zsh)"
echo "  2. Lancez ./post_relog.sh pour activer les extensions GNOME"
echo ""
echo "⚠️  Si première installation (pas de snapshot restic) :"
echo "  - Configurez /etc/fstab manuellement"
echo "  - Lancez save.sh après configuration pour créer le premier snapshot"
