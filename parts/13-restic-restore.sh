#!/bin/bash
# parts/13-restic-restore.sh — Restore user profiles and system configs via Restic

echo ""
echo "🔄 Restauration via Restic..."
export RESTIC_REPOSITORY="$BACKUP_DIR/restic-repo"

if ! restic snapshots &>/dev/null; then
  echo "⚠️  Aucun snapshot Restic trouvé. Première installation."
else
  RESTORE_TMP=$(mktemp -d /tmp/restic-restore.XXXXXX)

  echo "  ⏳ Restauration des profils utilisateurs..."
  restic restore latest --target "$RESTORE_TMP/home" \
    --include "$HOME/.config/sunshine" \
    --include "$HOME/.config/mozilla/firefox" \
    --include "$HOME/.thunderbird" \
    --include "$HOME/.config/libreoffice" \
    --include "$HOME/.config/calibre" \
    --include "$HOME/.config/lg-buddy" \
    --include "$HOME/.local/share/sigil-ebook" \
    --include "$HOME/.ssh/known_hosts" \
    2>/dev/null || true

  # Copy from temp to actual locations (safe, no / target)
  if [ -d "$RESTORE_TMP/home" ]; then
    rsync -a --mkpath-destination "$RESTORE_TMP/home/" "$HOME/" 2>/dev/null || true
  fi

  echo "  ⏳ Restauration des configs système chiffrées (IPs, VM, fstab)..."
  sudo --preserve-env=RESTIC_REPOSITORY,RESTIC_PASSWORD restic restore latest --target "$RESTORE_TMP/system" \
    --include "/var/lib/bluetooth" \
    --include "/etc/samba" \
    --include "/etc/fstab" \
    --include "/etc/systemd/system/mnt-calibreweb.mount" \
    --include "/etc/systemd/system/mnt-torrent.mount" \
    --include "/var/lib/libvirt/images/win11.qcow2" \
    --include "/etc/libvirt/qemu/win11.xml" \
    2>/dev/null || true

  if [ -d "$RESTORE_TMP/system" ]; then
    sudo rsync -a "$RESTORE_TMP/system/" / 2>/dev/null || true
  fi

  rm -rf "$RESTORE_TMP"
  sudo systemctl restart bluetooth 2>/dev/null || true
fi