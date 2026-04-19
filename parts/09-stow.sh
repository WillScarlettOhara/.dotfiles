#!/bin/bash
# parts/09-stow.sh — Apply dotfiles via stow

echo ""
echo "🔗 Application des dotfiles via stow..."
cd "$HOME/.dotfiles"
STOW_FOLDERS=(zsh tmux btop git nvim ghostty mpv lsd local-bin local-apps)

# --adopt moves any pre-existing target files (e.g. ~/.gitconfig created by
# step 6.5) into the stow package dir, then creates the symlinks.
# git checkout restores the repo versions so adopted files don't overwrite them.
LC_ALL=C stow --adopt "${STOW_FOLDERS[@]}"
git checkout .
