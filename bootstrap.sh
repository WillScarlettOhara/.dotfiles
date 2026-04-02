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
  zoxide wl-clipboard ttf-jetbrains-mono-nerd qt6ct
  nodejs npm python python-pip jre-openjdk luarocks tree-sitter
  tmux ghostty lazygit ripgrep lsd zsh-theme-powerlevel10k
  neovim-git mpv firefox thunderbird libreoffice-fresh sigil sunshine
  discord element-desktop
  xkb-qwerty-fr hunspell-en_gb hunspell-fr-comprehensive
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
  paru -S --needed "${PACKAGES[@]}"
else
  sudo pacman -Syu --noconfirm
  sudo pacman -S --needed "${PACKAGES[@]}"
fi

sudo -v && wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | sudo sh /dev/stdin

sudo modprobe fuse
grep -qxF "user_allow_other" /etc/fuse.conf || echo "user_allow_other" | sudo tee -a /etc/fuse.conf
echo "fuse" | sudo tee /etc/modules-load.d/fuse.conf >/dev/null

# ─── 1b. Rustup ─────────────────────────────────────────────────────────────
echo ""
echo "🦀 Installation de Rustup..."

# Garde-fou : désinstaller rust système s'il est présent (pacman ou dépendances)
if pacman -Qi rust &>/dev/null; then
  echo "  ⚠️  Rust système détecté, désinstallation avant rustup..."
  sudo pacman -Rdd --noconfirm rust 2>/dev/null || true
  # rust-analyzer pacman dépend de rust, on le retire aussi s'il est là
  sudo pacman -Rdd --noconfirm rust-analyzer 2>/dev/null || true
fi

# Installation interactive de rustup
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o /tmp/rustup-init.sh
sh /tmp/rustup-init.sh </dev/tty

if [ -f "$HOME/.cargo/env" ]; then
  # shellcheck source=/dev/null
  source "$HOME/.cargo/env"
else
  echo "❌ Rustup installation semble avoir échoué."
  exit 1
fi

rustup component add rust-analyzer
echo "  ✅ Rust $(rustc --version) + rust-analyzer installés via rustup"

# ─── 2. Configuration du clavier ────────────────────────────────────────────
echo ""
echo "⌨️  Configuration du clavier..."
if [ "$IS_GNOME" = true ]; then
  gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us+qwerty-fr')]" 2>/dev/null || true
  gsettings set org.gnome.desktop.interface monospace-font-name "JetBrainsMono Nerd Font 11" 2>/dev/null || true
else
  sudo localectl set-x11-keymap us pc105 qwerty-fr 2>/dev/null || true
fi
fc-cache -fq

# ─── 3. Pare-feu Sunshine ───────────────────────────────────────────────────
echo ""
echo "🔥 Configuration du pare-feu..."
if command -v firewall-cmd &>/dev/null; then
  sudo firewall-cmd --permanent --add-port={47984,47989,47990,48010}/tcp >/dev/null
  sudo firewall-cmd --permanent --add-port={47998,47999,48000}/udp >/dev/null
  sudo firewall-cmd --reload >/dev/null
elif command -v ufw &>/dev/null; then
  sudo ufw allow 47984,47989,47990,48010/tcp >/dev/null
  sudo ufw allow 47998,47999,48000/udp >/dev/null
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
      return
    fi
  fi

  sudo rm -f /usr/local/bin/bw 2>/dev/null || true
  wget -q "https://vault.bitwarden.com/download/?app=cli&platform=linux" -O /tmp/bw.zip
  unzip -q -o /tmp/bw.zip -d /tmp/bw_extract
  sudo install -m 755 /tmp/bw_extract/bw /usr/local/bin/bw
  rm -rf /tmp/bw.zip /tmp/bw_extract
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
    python "$HOME/.dotfiles/genKeyMap.py" us+qwerty-fr >~/.cache/gjs-osk/keycodes/us+qwerty-fr.json
  fi
fi

# ─── 9. Stow des dotfiles ───────────────────────────────────────────────────
echo ""
echo "🔗 Application des dotfiles via stow..."
cd "$HOME/.dotfiles"
STOW_FOLDERS=(zsh tmux btop git nvim ghostty mpv lsd local-bin local-apps systemd-user)
stow "${STOW_FOLDERS[@]}"

# ─── 10. Restauration système depuis Git ────────────────────────────────────
echo ""
echo "⚙️  Restauration des configs GNOME..."
if [ "$IS_GNOME" = true ]; then
  dconf load /org/gnome/shell/extensions/gjsosk/ <"$HOME/.dotfiles/gnome/gjsosk_settings.ini" 2>/dev/null || true
  dconf load /org/gnome/shell/extensions/dash-to-panel/ <"$HOME/.dotfiles/gnome/dash-to-panel_settings.ini" 2>/dev/null || true
  dconf load /org/gnome/shell/extensions/arcmenu/ <"$HOME/.dotfiles/gnome/arcmenu_settings.ini" 2>/dev/null || true
  dconf load /org/gnome/shell/extensions/vitals/ <"$HOME/.dotfiles/gnome/vitals_settings.ini" 2>/dev/null || true

  echo "⚙️  Application des préférences GNOME (Tweaks & UI)..."
  gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close' 2>/dev/null || true
  gsettings set org.gnome.desktop.peripherals.mouse accel-profile 'flat' 2>/dev/null || true
  gsettings set org.gnome.desktop.interface enable-animations false 2>/dev/null || true
  gsettings set org.gnome.desktop.interface cursor-size 48 2>/dev/null || true
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
  echo "  ✅ Préférences visuelles GNOME appliquées."
fi

# ─── 11. Secrets depuis Bitwarden (rclone + restic uniquement) ──────────────
echo ""
echo "🔐 Récupération des secrets Bitwarden..."

export RESTIC_PASSWORD
RESTIC_PASSWORD=$(bw list items --search "Restic Password" 2>/dev/null |
  jq -r '.[] | select(.name == "Restic Password") | (.notes // .login.password // empty)')

if [ -z "$RESTIC_PASSWORD" ]; then
  echo "❌ Mot de passe Restic introuvable. Abandon."
  exit 1
fi

mkdir -p ~/.config/rclone
bw list items --search "Config Rclone" 2>/dev/null |
  jq -r '.[] | select(.name == "Config Rclone") | .notes // empty' >~/.config/rclone/rclone.conf

# DNS — récupéré depuis Bitwarden
NETWORK_CONFIG=$(bw list items --search "Network Config" 2>/dev/null |
  jq -r '.[] | select(.name == "Network Config") | .notes // empty')
DNS_PRIMARY=$(echo "$NETWORK_CONFIG" | grep "^DNS_PRIMARY=" | cut -d= -f2)
DNS_FALLBACK=$(echo "$NETWORK_CONFIG" | grep "^DNS_FALLBACK=" | cut -d= -f2)

bw lock &>/dev/null # ← toujours en dernier

# DNS appliqué après bw lock
ACTIVE_CON=$(nmcli -t -f NAME connection show --active | head -n1)
nmcli connection modify "$ACTIVE_CON" \
  ipv4.dns "$DNS_PRIMARY $DNS_FALLBACK" \
  ipv4.ignore-auto-dns yes
nmcli connection up "$ACTIVE_CON"
sudo sed -i "s/^#*FallbackDNS=.*/FallbackDNS=$DNS_FALLBACK/" /etc/systemd/resolved.conf
grep -q "^FallbackDNS=" /etc/systemd/resolved.conf ||
  echo "FallbackDNS=$DNS_FALLBACK" | sudo tee -a /etc/systemd/resolved.conf
sudo systemctl restart systemd-resolved
echo "  ✅ DNS → $DNS_PRIMARY (principal) $DNS_FALLBACK (fallback)"

# ─── 12. Montage OneDrive ───────────────────────────────────────────────────
echo ""
echo "☁️  Démarrage de Rclone OneDrive..."
systemctl --user daemon-reload
systemctl --user enable --now rclone-onedrive.service

BACKUP_DIR="$HOME/OneDrive/Backup_PC"
while [ ! -d "$BACKUP_DIR" ]; do
  sleep 2
  echo -n "."
done
echo " ✅ OneDrive connecté !"

# ─── 13. Restauration Restic (Y compris .mount secrets) ─────────────────────
echo ""
echo "🔄 Restauration via Restic..."
export RESTIC_REPOSITORY="$BACKUP_DIR/restic-repo"

if ! restic snapshots &>/dev/null; then
  echo "⚠️  Aucun snapshot Restic trouvé. Première installation."
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
    2>/dev/null || true

  echo "  ⏳ Restauration des configs système chiffrées (IPs, VM, fstab)..."
  sudo --preserve-env=RESTIC_REPOSITORY,RESTIC_PASSWORD restic restore latest --target / \
    --include "/var/lib/bluetooth" \
    --include "/etc/samba" \
    --include "/etc/fstab" \
    --include "/etc/systemd/system/mnt-calibreweb.mount" \
    --include "/etc/systemd/system/mnt-torrent.mount" \
    --include "/var/lib/libvirt/images/win11.qcow2" \
    --include "/etc/libvirt/qemu/win11.xml" \
    2>/dev/null || true

  sudo systemctl restart bluetooth 2>/dev/null || true
fi

# ─── 14. Hyperviseur & Mounts ───────────────────────────────────────────────
echo ""
echo "🖥️  Préparation de l'hyperviseur et des mounts..."

sudo mkdir -p /mnt/calibreweb /mnt/torrent /mnt/2TB /mnt/samba/data
sudo chown "$USER:$USER" /mnt/calibreweb /mnt/torrent
sudo mkdir -p /etc/samba

VIRTIO_ISO="/var/lib/libvirt/images/virtio-win.iso"
if [ ! -f "$VIRTIO_ISO" ]; then
  sudo wget -q https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso -O "$VIRTIO_ISO"
  sudo chmod 644 "$VIRTIO_ISO"
fi

sudo systemctl daemon-reload
for mnt in mnt-calibreweb.mount mnt-torrent.mount; do
  if [ -f "/etc/systemd/system/$mnt" ]; then
    sudo systemctl enable --now "$mnt" 2>/dev/null || true
  fi
done

sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt,kvm "$USER"
if [ -f "/etc/libvirt/qemu/win11.xml" ]; then
  sudo chown root:root "/var/lib/libvirt/images/win11.qcow2" 2>/dev/null || true
  sudo virsh define "/etc/libvirt/qemu/win11.xml" 2>/dev/null || true
fi

if [ -f /etc/fstab ] && grep -q "ntfs3\|cifs" /etc/fstab 2>/dev/null; then
  sudo mount -a 2>/dev/null || true
fi

# ─── 15. LG Buddy ───────────────────────────────────────────────────────────
if [ "$IS_GNOME" = true ]; then
  echo ""
  echo "📺 Installation de LG Buddy..."
  sudo pacman -S --needed --noconfirm wakeonlan zenity
  git clone git@github.com:Faceless3882/LG_Buddy.git /tmp/LG_Buddy 2>/dev/null || git -C /tmp/LG_Buddy pull --ff-only
  chmod +x /tmp/LG_Buddy/install.sh /tmp/LG_Buddy/configure.sh

  if [ -f "$HOME/.config/lg-buddy/config.env" ]; then
    cat >/tmp/LG_Buddy/configure.sh <<'STUB'
#!/bin/bash
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/bin/LG_Buddy_Common"
CONFIG_FILE="$(lg_buddy_user_config_path)"
if [ -f "$HOME/.config/systemd/user/LG_Buddy_screen.service" ]; then
  systemctl --user daemon-reload
  systemctl --user restart LG_Buddy_screen.service 2>/dev/null || true
fi
STUB
    chmod +x /tmp/LG_Buddy/configure.sh
    printf 'Y\nN\n' | /tmp/LG_Buddy/install.sh
  else
    /tmp/LG_Buddy/install.sh
  fi
fi

# ─── 15. Stremio (AUR + patch CEF) ──────────────────────────────────────────
echo ""
echo "🎬 Installation de Stremio..."

install_stremio() {
  local dir="/tmp/stremio"

  git clone https://aur.archlinux.org/stremio-linux-shell-git.git "$dir" 2>/dev/null ||
    git -C "$dir" pull --ff-only

  (
    cd "$dir"

    # Vérification que le patch n'a pas déjà été appliqué
    if grep -q "LD_LIBRARY_PATH" PKGBUILD; then
      echo "  ℹ️  PKGBUILD déjà patché, skip."
    else
      python3 /tmp/stremio_patch.py || {
        echo "  ❌ Patch échoué."
        exit 1
      }
    fi

    makepkg -si --noconfirm
  )
}

# Script de patch écrit séparément pour éviter les problèmes de heredoc imbriqués
cat >/tmp/stremio_patch.py <<'PYEOF'
import re, pathlib, sys

NEW_PACKAGE = r"""package() {
  cd "stremio-linux-shell"
  install -Dm755 "target/release/stremio-linux-shell" "$pkgdir/usr/bin/stremio"
  install -Dm644 "data/com.stremio.Stremio.desktop" \
    "$pkgdir/usr/share/applications/com.stremio.Stremio.desktop"
  sed -i '/^[[:space:]]*DBusActivatable[[:space:]]*=[[:space:]]*true[[:space:]]*$/d' \
    "$pkgdir/usr/share/applications/com.stremio.Stremio.desktop"
  install -Dm644 "data/icons/com.stremio.Stremio.svg" \
    "$pkgdir/usr/share/icons/hicolor/scalable/apps/com.stremio.Stremio.svg"
  install -Dm644 "data/com.stremio.Stremio.metainfo.xml" \
    "$pkgdir/usr/share/metainfo/com.stremio.Stremio.metainfo.xml"
  install -Dm644 /usr/share/licenses/spdx/GPL-3.0-only.txt \
    "$pkgdir/usr/share/licenses/$pkgname/LICENSE.txt"
  install -dm755 "$pkgdir/usr/lib/stremio/cef"
  cp -r vendor/cef/* "$pkgdir/usr/lib/stremio/cef/"
  install -dm755 "$pkgdir/usr/lib/stremio"
  mv "$pkgdir/usr/bin/stremio" "$pkgdir/usr/lib/stremio/stremio-bin"
  install -Dm644 "data/server.js" "$pkgdir/usr/lib/stremio/server.js"
  cat > "$pkgdir/usr/bin/stremio" <<'EOF'
#!/bin/bash
export LD_LIBRARY_PATH="/usr/lib/stremio/cef:$LD_LIBRARY_PATH"
export CEF_FLAGS="--enable-features=ClipboardContentSetting --enable-clipboard --disable-gpu-sandbox"
cd /usr/lib/stremio
exec /usr/lib/stremio/stremio-bin $CEF_FLAGS "$@"
EOF
  chmod +x "$pkgdir/usr/bin/stremio"
}"""

pkgbuild_path = pathlib.Path("PKGBUILD")
pkgbuild = pkgbuild_path.read_text()
patched = re.sub(r"(?ms)^package\(\)\s*\{.*?^\}", NEW_PACKAGE, pkgbuild)

if patched == pkgbuild:
    print("  ❌ Section package() non trouvée dans le PKGBUILD.")
    sys.exit(1)

pkgbuild_path.write_text(patched)
print("  ✅ PKGBUILD patché avec succès.")
PYEOF

if command -v stremio &>/dev/null; then
  echo "  ✅ Stremio déjà installé, skip."
else
  install_stremio && echo "  ✅ Stremio installé." || echo "  ⚠️  Échec installation Stremio."
fi

# ─── Wakeup USB ─────────────────────────────────────────────────────────────
echo ""
echo "💤 Configuration du wakeup USB..."

# Trouve le contrôleur XHC qui gère le clavier (EPOMAKER TH80 Pro)
KEYBOARD_VENDOR="3151"
KEYBOARD_PRODUCT="4010"

KEYBOARD_BUS=$(lsusb | grep "${KEYBOARD_VENDOR}:${KEYBOARD_PRODUCT}" |
  grep -o 'Bus [0-9]*' | awk '{printf "%d", $2}')

if [ -n "$KEYBOARD_BUS" ]; then
  KEYBOARD_PCI=$(readlink "/sys/bus/usb/devices/usb${KEYBOARD_BUS}" 2>/dev/null |
    grep -o '[^/]*$')
  KEYBOARD_XHC=$(grep "$KEYBOARD_PCI" /proc/acpi/wakeup | awk '{print $1}')
  echo "  ⌨️  Clavier détecté sur $KEYBOARD_XHC ($KEYBOARD_PCI)"
else
  echo "  ⚠️  Clavier non détecté — XH00 conservé par défaut"
  KEYBOARD_XHC="XH00"
fi

# Désactive tous les XHC sauf celui du clavier
for dev in XHC0 XHC1 XHC3 XHC4 XH00; do
  if [ "$dev" != "$KEYBOARD_XHC" ]; then
    sudo sh -c "echo \"$dev\" > /proc/acpi/wakeup" 2>/dev/null || true
  fi
done

# Désactive wakeup Bluetooth
BT_PATH=$(find /sys/bus/usb/devices/ -name "product" 2>/dev/null |
  while read -r f; do
    grep -qi "bluetooth" "$f" && dirname "$f"
  done | head -1)

if [ -n "$BT_PATH" ]; then
  echo disabled | sudo tee "$BT_PATH/power/wakeup" >/dev/null 2>&1 || true
  echo "  ✅ Wakeup Bluetooth désactivé ($BT_PATH)"
fi

# Service permanent
sudo tee /etc/systemd/system/disable-usb-wakeup.service >/dev/null <<'EOF'
[Unit]
Description=Disable USB wakeup (keep keyboard controller)
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c '
  KEYBOARD_BUS=$(lsusb | grep "3151:4010" | grep -o "Bus [0-9]*" | awk "{printf \"%d\", \$2}")
  KEYBOARD_PCI=$(readlink "/sys/bus/usb/devices/usb${KEYBOARD_BUS}" 2>/dev/null | grep -o "[^/]*$")
  KEYBOARD_XHC=$(grep "$KEYBOARD_PCI" /proc/acpi/wakeup | awk "{print \$1}")
  [ -z "$KEYBOARD_XHC" ] && KEYBOARD_XHC="XH00"
  for dev in XHC0 XHC1 XHC3 XHC4 XH00; do
    [ "$dev" != "$KEYBOARD_XHC" ] && echo "$dev" > /proc/acpi/wakeup
  done
  BT_PATH=$(find /sys/bus/usb/devices/ -name "product" 2>/dev/null | while read -r f; do grep -qi "bluetooth" "$f" && dirname "$f"; done | head -1)
  [ -n "$BT_PATH" ] && echo disabled > "$BT_PATH/power/wakeup" || true
'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable --now disable-usb-wakeup.service
echo "  ✅ Wakeup USB configuré (clavier $KEYBOARD_XHC conservé)"

# ─── 16. Shell par défaut ───────────────────────────────────────────────────
echo ""
echo "🐚 Configuration de zsh comme shell par défaut..."
ZSH_PATH=$(which zsh)
grep -qxF "$ZSH_PATH" /etc/shells || echo "$ZSH_PATH" | sudo tee -a /etc/shells
sudo usermod -s "$ZSH_PATH" "$USER"

echo ""
echo "========================================================="
echo "🎉 RESTAURATION TOTALE TERMINÉE !"
echo "========================================================="
