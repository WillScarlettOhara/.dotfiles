#!/bin/bash
# bootstrap.sh — Nouvelle installation from scratch
# Résout le problème : besoin SSH pour GitHub, besoin GitHub pour les dotfiles
#
# Prérequis :
#   - Avoir un item de type "Clé SSH" (Type 5) dans Bitwarden
#   - Nommé "SSH GitHub", avec les champs "Clé Privée" et "Clé Publique" remplis.

set -e
export NODE_NO_WARNINGS=1

echo "======================================"
echo "🚀 Bootstrap nouvelle installation"
echo "======================================"

# ─── 1. Dépendances minimales ───────────────────────────────────────────────
echo ""
echo "📦 Installation des dépendances..."
sudo pacman -S --noconfirm jq stow git openssh sshfs unzip wget 2>/dev/null ||
  sudo apt install -y jq stow git openssh-client sshfs unzip wget 2>/dev/null || true

# ─── 2. Bitwarden CLI ───────────────────────────────────────────────────────
echo ""
echo "🔐 Installation Bitwarden CLI (binaire officiel)..."
if ! command -v bw &>/dev/null; then
  BW_VERSION="2026.2.0"
  wget -q "https://github.com/bitwarden/clients/releases/download/cli-v${BW_VERSION}/bw-linux-${BW_VERSION}.zip" -O /tmp/bw.zip
  unzip -q /tmp/bw.zip -d /tmp/bw
  sudo install -m 755 /tmp/bw/bw /usr/local/bin/bw
  rm -rf /tmp/bw.zip /tmp/bw
  echo "  ✅ Bitwarden CLI ${BW_VERSION} installé"
else
  echo "  ✅ Bitwarden CLI déjà présent ($(bw --version))"
fi

# ─── 3. Login + unlock Bitwarden ────────────────────────────────────────────
echo ""
echo "🔑 Connexion à Bitwarden..."
BW_STATUS=$(bw status | jq -r '.status')

if [[ "$BW_STATUS" == "unauthenticated" ]]; then
  bw login
fi

echo ""
echo "🔓 Déverrouillage du vault..."
echo -n "  Entrez votre mot de passe maître : "
read -s -r BW_PASS </dev/tty
echo ""
export BW_PASS
BW_SESSION=$(bw unlock --raw --passwordenv BW_PASS)
unset BW_PASS
export BW_SESSION

if [[ -z "$BW_SESSION" ]]; then
  echo "❌ Échec du déverrouillage. Essayez manuellement :"
  echo "   export BW_SESSION=\$(bw unlock --raw)"
  echo "   bash bootstrap.sh"
  exit 1
fi

bw sync &>/dev/null
echo "  ✅ Vault déverrouillé."

# ─── 4. Récupération des clés SSH depuis Bitwarden ──────────────────────────
echo ""
echo "🗝️  Récupération des clés SSH depuis Bitwarden..."
mkdir -p ~/.ssh
chmod 700 ~/.ssh

ITEM_NAME="SSH GitHub"

# Extraction native (plus besoin de base64)
PRIVATE_KEY=$(bw get item "$ITEM_NAME" | jq -r '.sshKey.privateKey // empty')

if [[ -z "$PRIVATE_KEY" ]]; then
  echo "  ⚠️  Item '$ITEM_NAME' introuvable. Items disponibles :"
  bw list items | jq -r '.[].name'
  echo ""
  read -rp "  Entrez le nom exact de l'item SSH : " ITEM_NAME </dev/tty
  PRIVATE_KEY=$(bw get item "$ITEM_NAME" | jq -r '.sshKey.privateKey // empty')
fi

if [[ -n "$PRIVATE_KEY" ]]; then
  echo "$PRIVATE_KEY" >~/.ssh/id_rsa
  chmod 600 ~/.ssh/id_rsa
  echo "  ✅ Clé privée restaurée dans ~/.ssh/id_rsa"
else
  echo "  ❌ Impossible de récupérer la clé SSH privée"
  exit 1
fi

# Extraction de la clé publique native
PUBLIC_KEY=$(bw get item "$ITEM_NAME" | jq -r '.sshKey.publicKey // empty')
if [[ -n "$PUBLIC_KEY" ]]; then
  echo "$PUBLIC_KEY" >~/.ssh/id_rsa.pub
  chmod 644 ~/.ssh/id_rsa.pub
  echo "  ✅ Clé publique restaurée dans ~/.ssh/id_rsa.pub"
fi

# Ajoute GitHub et les serveurs locaux aux known_hosts
echo ""
echo "  Ajout des known_hosts (GitHub + serveurs locaux)..."
ssh-keyscan github.com >>~/.ssh/known_hosts 2>/dev/null
ssh-keyscan REDACTED >>~/.ssh/known_hosts 2>/dev/null
ssh-keyscan REDACTED >>~/.ssh/known_hosts 2>/dev/null
chmod 644 ~/.ssh/known_hosts
echo "  ✅ known_hosts mis à jour"

sudo mkdir -p /root/.ssh
sudo sh -c "ssh-keyscan REDACTED >> /root/.ssh/known_hosts 2>/dev/null"
sudo sh -c "ssh-keyscan REDACTED >> /root/.ssh/known_hosts 2>/dev/null"
echo "  ✅ known_hosts root mis à jour"

# Test connexion GitHub
echo ""
echo "  Test connexion GitHub..."
if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
  echo "  ✅ Connexion GitHub OK"
else
  echo "  ⚠️  Vérifiez manuellement : ssh -T git@github.com"
fi

# ─── 5. Clone des dotfiles ──────────────────────────────────────────────────
echo ""
echo "📂 Clone des dotfiles..."
if [[ -d "$HOME/.dotfiles" ]]; then
  echo "  ~/.dotfiles existe déjà, mise à jour..."
  git -C "$HOME/.dotfiles" pull
else
  git clone git@github.com:WillScarlettOhara/.dotfiles.git "$HOME/.dotfiles"
fi

# ─── 6. Application des dotfiles via stow ───────────────────────────────────
echo ""
echo "🔗 Application des dotfiles via stow..."
cd "$HOME/.dotfiles"
stow --adopt zsh tmux git nvim kitty mpv lsd 2>/dev/null ||
  stow zsh tmux git nvim kitty mpv lsd
echo "  ✅ Dotfiles appliqués"

# ─── 7. Verrouillage Bitwarden ──────────────────────────────────────────────
bw lock &>/dev/null
echo ""
echo "  🔒 Vault Bitwarden verrouillé"

echo ""
echo "======================================"
echo "✅ Bootstrap terminé !"
echo "======================================"

