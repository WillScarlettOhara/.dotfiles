#!/bin/bash
# bootstrap.sh — Nouvelle installation from scratch
# Résout le problème : besoin SSH pour GitHub, besoin GitHub pour les dotfiles
#
# Prérequis :
#   - Avoir stocké les clés SSH dans Bitwarden (interface web vault.bitwarden.com)
#     sous le nom "SSH GitHub" en Secure Note avec :
#       - Notes : contenu de `cat ~/.ssh/id_rsa | base64 -w 0`
#       - Champ personnalisé "PUBLIC_KEY" : contenu de `cat ~/.ssh/id_rsa.pub`

set -e
export NODE_NO_WARNINGS=1

echo "======================================"
echo "🚀 Bootstrap nouvelle installation"
echo "======================================"

# ─── 1. Dépendances minimales ───────────────────────────────────────────────
echo ""
echo "📦 Installation des dépendances..."
sudo pacman -S --noconfirm jq stow git openssh nodejs npm 2>/dev/null || \
  sudo apt install -y jq stow git openssh-client nodejs npm 2>/dev/null || true

# ─── 2. Bitwarden CLI ───────────────────────────────────────────────────────
echo ""
echo "🔐 Installation Bitwarden CLI..."
if ! command -v bw &>/dev/null; then
  sudo npm install -g @bitwarden/cli
fi

# ─── 3. Login + unlock Bitwarden ────────────────────────────────────────────
echo ""
echo "🔑 Connexion à Bitwarden..."
echo "  (Entrez votre email et mot de passe maître)"

BW_STATUS=$(bw status | jq -r '.status')

if [[ "$BW_STATUS" == "unauthenticated" ]]; then
  bw login
fi

echo ""
echo "🔓 Déverrouillage du vault..."
echo "  ⚠️  Entrez votre mot de passe maître ci-dessous :"
BW_SESSION=""
BW_SESSION=$(bw unlock --raw </dev/tty)
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

# Clé privée stockée en base64 dans les notes
PRIVATE_KEY_B64=$(bw get item "$ITEM_NAME" | jq -r '.notes // empty')

if [[ -z "$PRIVATE_KEY_B64" ]]; then
  echo "  ⚠️  Item '$ITEM_NAME' introuvable. Items disponibles :"
  bw list items | jq -r '.[].name'
  echo ""
  read -rp "  Entrez le nom exact de l'item SSH : " ITEM_NAME </dev/tty
  PRIVATE_KEY_B64=$(bw get item "$ITEM_NAME" | jq -r '.notes // empty')
fi

if [[ -n "$PRIVATE_KEY_B64" ]]; then
  echo "$PRIVATE_KEY_B64" | base64 -d > ~/.ssh/id_rsa
  chmod 600 ~/.ssh/id_rsa
  echo "  ✅ Clé privée restaurée dans ~/.ssh/id_rsa"
else
  echo "  ❌ Impossible de récupérer la clé SSH privée"
  exit 1
fi

# Clé publique stockée dans un champ personnalisé
PUBLIC_KEY=$(bw get item "$ITEM_NAME" | jq -r '.fields[] | select(.name == "PUBLIC_KEY") | .value // empty')
if [[ -n "$PUBLIC_KEY" ]]; then
  echo "$PUBLIC_KEY" > ~/.ssh/id_rsa.pub
  chmod 644 ~/.ssh/id_rsa.pub
  echo "  ✅ Clé publique restaurée dans ~/.ssh/id_rsa.pub"
fi

# Ajoute GitHub aux known_hosts
ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
chmod 644 ~/.ssh/known_hosts

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
stow --adopt zsh tmux git nvim kitty mpv lsd 2>/dev/null || \
  stow zsh tmux git nvim kitty mpv lsd
echo "  ✅ Dotfiles appliqués"

# ─── 7. Verrouillage Bitwarden ──────────────────────────────────────────────
bw lock &>/dev/null
echo ""
echo "  🔒 Vault Bitwarden verrouillé"

echo ""
echo "======================================"
echo "✅ Bootstrap terminé !"
echo ""
echo "Prochaines étapes :"
echo "  1. source ~/.zshrc"
echo "  2. Monter OneDrive : systemctl --user start rclone-onedrive.service"
echo "  3. Lancer le script de restauration OneDrive"
echo "  4. Installer les packages : paru -S - < ~/.dotfiles/pkglist.txt"
echo "======================================"