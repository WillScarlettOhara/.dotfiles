#!/bin/bash
# parts/09-stow.sh — Apply dotfiles via stow

echo ""
echo "🔗 Application des dotfiles via stow..."
cd "$HOME/.dotfiles"

STOW_FOLDERS=(zsh tmux btop git nvim ghostty mpv lsd local-bin local-apps)

# 1. Résolution des conflits : Sauvegarde des fichiers bloquants
echo "📦 Vérification des conflits..."
for file in ".zshrc" ".gitconfig" ".bashrc"; do
  if [ -f "$HOME/$file" ] && [ ! -L "$HOME/$file" ]; then
    echo "   ⚠️ Fichier existant détecté : ~/$file. Déplacement vers ~/${file}.bak"
    mv "$HOME/$file" "$HOME/${file}.bak"
  fi
done

# 2. Application de stow
stow "${STOW_FOLDERS[@]}"
