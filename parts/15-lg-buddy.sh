#!/bin/bash
# parts/15-lg-buddy.sh — LG Buddy installation for GNOME

if [ "$IS_GNOME" != true ]; then
  return 0
fi

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
