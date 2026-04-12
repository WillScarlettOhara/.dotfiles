#!/bin/bash
# parts/09-stow.sh — Apply dotfiles via stow

echo ""
echo "🔗 Application des dotfiles via stow..."
cd "$HOME/.dotfiles"
STOW_FOLDERS=(zsh tmux btop git nvim ghostty mpv lsd local-bin local-apps)
stow "${STOW_FOLDERS[@]}"