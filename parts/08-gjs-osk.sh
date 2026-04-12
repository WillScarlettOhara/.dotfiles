#!/bin/bash
# parts/08-gjs-osk.sh — GNOME on-screen keyboard extension

if [ "$IS_GNOME" != true ]; then
  exit 0
fi

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