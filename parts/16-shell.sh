#!/bin/bash
# parts/16-shell.sh — Set zsh as default shell

echo ""
echo "🐚 Configuration de zsh comme shell par défaut..."
ZSH_PATH=$(which zsh)
grep -qxF "$ZSH_PATH" /etc/shells || echo "$ZSH_PATH" | sudo tee -a /etc/shells
sudo usermod -s "$ZSH_PATH" "$USER"