#!/bin/bash
# bootstrap.sh — Installation "Zero-Touch" from scratch
# Usage : curl -fsSL https://raw.githubusercontent.com/WillScarlettOhara/.dotfiles/master/bootstrap.sh | bash
#
# Steps 0-7 are inline (must work pre-clone for curl|bash).
# Steps 8+ are sourced from parts/ after the dotfiles repo is cloned.

set -euo pipefail
export NODE_NO_WARNINGS=1

cleanup() {
  # Ensure Bitwarden is locked on any exit
  bw lock &>/dev/null || true
}
trap cleanup EXIT

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
    gnome-shell-extension-color-picker
    gnome-shell-extension-soft-brightness-plus
    gnome-shell-extension-user-themes
    gnome-clocks
    extension-manager
  )
fi

if command -v paru &>/dev/null; then
  paru -Syu --noconfirm
  paru -S --needed --noconfirm --skipreview "${PACKAGES[@]}"
else
  sudo pacman -Syu --noconfirm
  sudo pacman -S --needed --noconfirm --skipreview "${PACKAGES[@]}"
fi

# ─── 1.5 Installation / Mise à jour d'OpenCode ──────────────────────────────
echo ""
echo "🤖 Vérification d'OpenCode..."

install_opencode() {
  local latest_version
  # Récupération de la dernière version via npm (qui est silencieux)
  latest_version=$(npm show opencode-ai version 2>/dev/null || echo "0.0.0")

  if command -v opencode &>/dev/null; then
    local current_version
    # Extraction propre des chiffres de la version actuelle (ex: 1.14.18)
    current_version=$(opencode --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "0.0.0")
    
    if [ "$current_version" = "$latest_version" ] && [ "$current_version" != "0.0.0" ]; then
      echo "  ✅ OpenCode est déjà à jour (v$current_version), skip."
      return
    fi
    echo "  🔄 Mise à jour d'OpenCode (v$current_version -> v$latest_version)..."
  else
    echo "  📥 Installation d'OpenCode..."
  fi

  # Redirection de l'entrée standard pour éviter le syndrome du script "mangé"
  curl -fsSL https://opencode.ai/install | bash < /dev/null
}
install_opencode

sudo -v && wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | sudo sh /dev/stdin

sudo modprobe fuse
grep -qxF "user_allow_other" /etc/fuse.conf || echo "user_allow_other" | sudo tee -a /etc/fuse.conf
echo "fuse" | sudo tee /etc/modules-load.d/fuse.conf >/dev/null

# ─── 1b. Rustup ─────────────────────────────────────────────────────────────
echo ""
echo "🦀 Installation de Rustup..."

if command -v rustup &>/dev/null && command -v rust-analyzer &>/dev/null; then
  echo "  ✅ Rustup et rust-analyzer déjà installés, skip."
else
  if pacman -Qi rust &>/dev/null; then
    echo "  ⚠️  Rust système détecté, désinstallation avant rustup..."
    sudo pacman -Rdd --noconfirm rust 2>/dev/null || true
    sudo pacman -Rdd --noconfirm rust-analyzer 2>/dev/null || true
  fi

  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o /tmp/rustup-init.sh
  sh /tmp/rustup-init.sh -y

  if [ -f "$HOME/.cargo/env" ]; then
    # shellcheck source=/dev/null
    source "$HOME/.cargo/env"
  else
    echo "❌ Rustup installation semble avoir échoué."
    exit 1
  fi

  rustup component add rust-analyzer
  echo "  ✅ Rust $(rustc --version) + rust-analyzer installés via rustup"
fi

# ─── 2. Configuration du clavier ────────────────────────────────────────────
echo ""
echo "⌨️  Configuration du clavier..."
if [ "$IS_GNOME" = true ]; then
  gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us+qwerty-fr')]" 2>/dev/null || true
  gsettings set org.gnome.desktop.interface monospace-font-name "JetBrainsMono Nerd Font 11" 2>/dev/null || true
else
  sudo localectl set-x11-keymap us pc105 qwerty-fr 2>/dev/null || true
fi
fc-cache -f

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

pass_file=$(mktemp /tmp/bw_pass.XXXXXX)
chmod 600 "$pass_file"

BW_STATUS=$(bw status | jq -r '.status' 2>/dev/null || echo "error")
if [ "$BW_STATUS" = "unauthenticated" ]; then
  bw login </dev/tty
fi

echo -n "🔓 Vault verrouillé. Entrez votre mot de passe maître : " >/dev/tty
read -s -r BW_PASS </dev/tty
echo "" >/dev/tty
echo "$BW_PASS" > "$pass_file"
unset BW_PASS

BW_SESSION=$(bw unlock --raw --passwordfile "$pass_file")
export BW_SESSION
shred -u "$pass_file" 2>/dev/null || rm -f "$pass_file"

if [ -z "${BW_SESSION:-}" ]; then
  echo "❌ Échec du déverrouillage."
  exit 1
fi
bw sync --session "$BW_SESSION" &>/dev/null

# ─── 6. Clés SSH depuis Bitwarden ───────────────────────────────────────────
echo ""
echo "🗝️  Récupération des clés SSH..."
mkdir -p ~/.ssh && chmod 700 ~/.ssh

BW_SSH_JSON=$(bw list items --search "SSH GitHub" --session "$BW_SESSION" 2>/dev/null |
  jq -r '.[] | select(.name == "SSH GitHub")')
echo "$BW_SSH_JSON" | jq -r '.sshKey.privateKey // empty' >~/.ssh/id_rsa
echo "$BW_SSH_JSON" | jq -r '.sshKey.publicKey  // empty' >~/.ssh/id_rsa.pub
chmod 600 ~/.ssh/id_rsa && chmod 644 ~/.ssh/id_rsa.pub

ssh-keyscan github.com >>~/.ssh/known_hosts 2>/dev/null
chmod 644 ~/.ssh/known_hosts

sudo cp ~/.ssh/id_rsa /root/.ssh/id_rsa && sudo chown root:root /root/.ssh/id_rsa
sudo chmod 600 /root/.ssh/id_rsa

# ─── 6.5 Configuration de Git (Anonymisation) ───────────────────────────────
echo ""
echo "🛡️  Configuration de Git (Anonymisation Github)..."
if [ -z "$(git config --global --get user.name)" ]; then
  git config --global user.name "WillScarlettOhara"
  git config --global user.email "39462014+WillScarlettOhara@users.noreply.github.com"
  echo "  ✅ Identité Git configurée sur l'adresse privée (noreply)."
else
  echo "  ℹ️  Identité Git existante conservée ($(git config --global --get user.name))."
fi

# ─── 7. Clone des dotfiles ──────────────────────────────────────────────────
echo ""
echo "📂 Clone des dotfiles depuis GitHub..."
if [ ! -d "$HOME/.dotfiles" ]; then
  git clone git@github.com:WillScarlettOhara/.dotfiles.git "$HOME/.dotfiles" < /dev/null
fi

# ─── 8+. Modules depuis parts/ ───────────────────────────────────────────────
# Now that dotfiles are cloned, source shared functions and modular parts

DOTFILES_DIR="$HOME/.dotfiles"

# Source common lib (provides: log, wait_for_dir, install_packages, etc.)
# shellcheck source=lib/common.sh
source "$DOTFILES_DIR/lib/common.sh"

# Source all parts in order
for part in "$DOTFILES_DIR/parts"/[0-9]*.sh; do
  if [ -f "$part" ]; then
    # shellcheck source=/dev/null
    source "$part"
  fi
done

echo ""
echo "========================================================="
echo "🎉 RESTAURATION TOTALE TERMINÉE !"
echo "========================================================="
