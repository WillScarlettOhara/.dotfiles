#!/bin/bash
# parts/10-gnome-restore.sh — Restore GNOME settings via dconf/gsettings

if [ "$IS_GNOME" != true ]; then
  exit 0
fi

echo ""
echo "⚙️  Restauration des configs GNOME..."

declare -A DCONF_MAP=(
  ["/org/gnome/shell/extensions/gjsosk/"]="gjsosk_settings.ini"
  ["/org/gnome/shell/extensions/dash-to-panel/"]="dash-to-panel_settings.ini"
  ["/org/gnome/shell/extensions/arcmenu/"]="arcmenu_settings.ini"
  ["/org/gnome/shell/extensions/vitals/"]="vitals_settings.ini"
  ["/org/gnome/shell/extensions/color-picker@tuberry/"]="color-picker_settings.ini"
  ["/org/gnome/shell/extensions/soft-brightness-plus@joelkitching.com/"]="soft-brightness_settings.ini"
  ["/org/gnome/shell/extensions/user-theme@gnome-shell-extensions.gcampax.github.com/"]="user-themes_settings.ini"
  ["/org/gnome/shell/extensions/appindicatorsupport@rgcjonas.gmail.com/"]="appindicator_settings.ini"
  ["/org/gnome/shell/extensions/copyous@boerdereinar.dev/"]="copyous_settings.ini"
)

GNOME_DIR="$HOME/.dotfiles/gnome"

for path in "${!DCONF_MAP[@]}"; do
  ini_file="$GNOME_DIR/${DCONF_MAP[$path]}"
  if [ -f "$ini_file" ]; then
    dconf load "$path" <"$ini_file" 2>/dev/null || true
  else
    echo "  ⚠️  $ini_file introuvable, skip."
  fi
done

echo "⚙️  Application des préférences GNOME (Tweaks & UI)..."
gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close' 2>/dev/null || true
gsettings set org.gnome.desktop.peripherals.mouse accel-profile 'flat' 2>/dev/null || true
gsettings set org.gnome.desktop.interface enable-animations false 2>/dev/null || true
gsettings set org.gnome.desktop.interface cursor-size 48 2>/dev/null || true
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
echo "  ✅ Préférences visuelles GNOME appliquées."