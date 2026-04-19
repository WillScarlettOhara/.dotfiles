#!/bin/bash
# parts/12-rclone-onedrive.sh — Configure Rclone OneDrive systemd service

echo ""
echo "☁️  Configuration de Rclone OneDrive..."

sudo tee /etc/systemd/system/rclone-onedrive.service >/dev/null <<EOF
[Unit]
Description=RClone OneDrive (Files on Demand)
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
User=$USER
ExecStartPre=/bin/bash -c 'fusermount3 -uz $HOME/OneDrive 2>/dev/null || true'
ExecStartPre=/usr/bin/mkdir -p $HOME/OneDrive
ExecStart=/usr/bin/rclone mount OneDrive: $HOME/OneDrive \\
  --config=$HOME/.config/rclone/rclone.conf \\
  --allow-non-empty \\
  --vfs-cache-mode full \\
  --vfs-cache-max-size 50G \\
  --vfs-cache-max-age 24h \\
  --dir-cache-time 1000h \\
  --attr-timeout 1h \\
  --poll-interval 15s \\
  --vfs-fast-fingerprint \\
  --onedrive-delta \\
  --vfs-refresh \\
  --user-agent "ISV|rclone.org|rclone/v1.73.3" \\
  --no-checksum \\
  --no-modtime \\
  --transfers 4 \\
  --rc \\
  --rc-no-auth \\
  --rc-web-gui \\
  --buffer-size 16M \\
  --allow-other \\
  --log-level INFO \\
  --log-file $HOME/.local/share/rclone-onedrive.log
ExecStop=/bin/fusermount3 -u $HOME/OneDrive
Restart=always
RestartSec=10
StartLimitBurst=0

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now rclone-onedrive.service

echo "  ⏳ Attente de la connexion à OneDrive..."
BACKUP_DIR="$HOME/OneDrive/Backup_PC"
if ! wait_for_dir "$BACKUP_DIR" 60; then
  echo "⚠️  OneDrive non disponible — nettoyage du cache et relance..."
  sudo systemctl stop rclone-onedrive.service
  rm -rf "$HOME/.cache/rclone/vfs" "$HOME/.cache/rclone/dir-cache"
  sudo systemctl start rclone-onedrive.service
  if ! wait_for_dir "$BACKUP_DIR" 60; then
    echo "❌ OneDrive non disponible. Abandon."
    return 1
  fi
fi
echo " ✅ OneDrive connecté !"
