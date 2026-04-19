#!/bin/bash
# parts/13-restic-restore.sh — Restore user profiles and system configs via Restic

echo ""
echo "🔄 Restauration via Restic..."
export RESTIC_REPOSITORY="rclone:OneDrive:Backup_PC/restic-repo"

if ! restic snapshots &>/dev/null; then
  echo "  ⚠️  Aucun snapshot Restic trouvé. Première installation."
  return 0
fi

echo "  ⏳ Restauration des profils utilisateurs..."
# Restic replace nativement les fichiers aux bons endroits grâce aux chemins absolus.
# On pointe directement sur / comme cible (sans danger car il ne restaure QUE les --include)
restic restore latest --target / \
  --include "$HOME/.config/opencode" \
  --include "$HOME/.local/share/opencode/auth.json" \
  --include "$HOME/.config/sunshine" \
  --include "$HOME/.config/mozilla/firefox" \
  --include "$HOME/.thunderbird" \
  --include "$HOME/.config/libreoffice" \
  --include "$HOME/.config/calibre" \
  --include "$HOME/.config/lg-buddy" \
  --include "$HOME/.local/share/sigil-ebook" \
  --include "$HOME/.ssh/known_hosts" \
  > /dev/null || true

echo "  ⏳ Restauration des configs système chiffrées (IPs, VM, fstab)..."
sudo --preserve-env=RESTIC_REPOSITORY,RESTIC_PASSWORD restic restore latest --target / \
  --include "/var/lib/bluetooth" \
  --include "/etc/samba" \
  --include "/etc/fstab" \
  --include "/etc/systemd/system/mnt-calibreweb.mount" \
  --include "/etc/systemd/system/mnt-torrent.mount" \
  --include "/var/lib/libvirt/images/win11.qcow2" \
  --include "/etc/libvirt/qemu/win11.xml" \
  > /dev/null || true

# Recharger systemd au cas où des fichiers .mount auraient été restaurés
sudo systemctl daemon-reload 2>/dev/null || true
sudo systemctl restart bluetooth 2>/dev/null || true
