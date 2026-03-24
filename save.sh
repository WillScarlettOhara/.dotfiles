#!/bin/bash

BACKUP_DIR="$HOME/OneDrive/Linux_Backup_2026"
LOG_FILE="$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).log"

RSYNC_CMD=(rsync -auL --delete --stats)
RSYNC_FIREFOX=(rsync -auL --delete --stats
  --exclude=cache2/
  --exclude=Cache/
  --exclude='*.sqlite-wal'
  --exclude='*.sqlite-shm'
  --exclude='*.sqlite-journal'
  --exclude=minidumps/
  --exclude=crashes/
  --exclude='Crash Reports/'
  --exclude='Pending Pings/'
  --exclude=thumbnails/
  --exclude=sessionstore-backups/
  --exclude=SiteSecurityServiceState.bin
  --exclude=AlternateServices.bin)
RSYNC_THUNDERBIRD=(rsync -auL --delete --stats
  --exclude=cache/
  --exclude=Cache/
  --exclude=lock
  --exclude=parent.lock
  --exclude='*.sqlite-wal'
  --exclude='*.sqlite-shm'
  --exclude=shader-cache/
  --exclude=datareporting/
  --exclude=saved-telemetry-pings/
  --exclude=crashes/
  --exclude=minidumps/
  --exclude=scheduled-notifications/
  --exclude=session.json
  --exclude=session.json.backup
  --exclude='ImapMail/'
  --exclude='ImapMail/*/tmp/')

log() {
  printf "%s\n" "$1" | tee -a "$LOG_FILE"
}

run() {
  local label="$1"
  shift
  log "  $label"
  if "$@" >>"$LOG_FILE" 2>&1; then
    log "  ✅ OK"
  else
    log "  ⚠️  Erreurs (voir log)"
  fi
}

mkdir -p "$BACKUP_DIR"/{Dotfiles,Configs_App,Scripts_et_Raccourcis,Services_Systemd/User,Services_Systemd/System,Profils_Lourds,Secrets,Sigil,GJS_OSK,Machines_Virtuelles}

log "======================================"
log "🚀 Démarrage : $(date '+%d/%m/%Y %H:%M:%S')"
log "======================================"

log ""
log "📄 Dotfiles..."
run ".zshrc / .p10k.zsh / .gitconfig" "${RSYNC_CMD[@]}" ~/.zshrc ~/.p10k.zsh ~/.gitconfig "$BACKUP_DIR/Dotfiles/"
run ".tmux.conf" "${RSYNC_CMD[@]}" --exclude='.tmux/plugins/' ~/.tmux.conf "$BACKUP_DIR/Dotfiles/"

log ""
log "⚙️  Configs App..."
run "nvim" "${RSYNC_CMD[@]}" ~/.config/nvim "$BACKUP_DIR/Configs_App/"
run "kitty" "${RSYNC_CMD[@]}" ~/.config/kitty "$BACKUP_DIR/Configs_App/"
run "lsd" "${RSYNC_CMD[@]}" ~/.config/lsd "$BACKUP_DIR/Configs_App/" || true
run "mpv" "${RSYNC_CMD[@]}" ~/.config/mpv "$BACKUP_DIR/Configs_App/" || true
run "starship" "${RSYNC_CMD[@]}" ~/.config/starship.toml "$BACKUP_DIR/Configs_App/" || true

log ""
log "🔧 Scripts et raccourcis..."
run "$HOME/.local/bin" "${RSYNC_CMD[@]}" ~/.local/bin/ "$BACKUP_DIR/Scripts_et_Raccourcis/bin/"
run "$HOME/.local/share/applications" "${RSYNC_CMD[@]}" ~/.local/share/applications/ "$BACKUP_DIR/Scripts_et_Raccourcis/applications/"

log ""
log "🔄 Services Systemd utilisateur..."
run "systemd/user" "${RSYNC_CMD[@]}" ~/.config/systemd/user/ "$BACKUP_DIR/Services_Systemd/User/"

log ""
log "🔄 Services Systemd système (mounts SSHFS)..."
run "systemd/system *.mount" sudo "${RSYNC_CMD[@]}" /etc/systemd/system/*.mount "$BACKUP_DIR/Services_Systemd/System/"
sudo chown -R "$USER:$USER" "$BACKUP_DIR/Services_Systemd/System/" 2>/dev/null || true

log ""
log "💾 fstab (disques NTFS, samba, btrfs)..."
run "fstab" sudo "${RSYNC_CMD[@]}" /etc/fstab "$BACKUP_DIR/Services_Systemd/"
sudo chown "$USER:$USER" "$BACKUP_DIR/Services_Systemd/fstab" 2>/dev/null || true

log ""
log "🦊 Firefox..."
run "firefox profiles.ini" "${RSYNC_CMD[@]}" ~/.config/mozilla/firefox/profiles.ini ~/.config/mozilla/firefox/installs.ini "$BACKUP_DIR/Profils_Lourds/firefox/"
run "firefox profil actif" "${RSYNC_FIREFOX[@]}" ~/.config/mozilla/firefox/d91w3rmx.default-release-1739246972176 "$BACKUP_DIR/Profils_Lourds/firefox/"

log ""
log "📧 Thunderbird..."
run "thunderbird profiles.ini" "${RSYNC_CMD[@]}" ~/.thunderbird/profiles.ini ~/.thunderbird/installs.ini "$BACKUP_DIR/Profils_Lourds/thunderbird/" || true
run "thunderbird profil actif" "${RSYNC_THUNDERBIRD[@]}" ~/.thunderbird/o2dmdq0v.default-release "$BACKUP_DIR/Profils_Lourds/thunderbird/"

log ""
log "📚 LibreOffice et Calibre..."
run "libreoffice" "${RSYNC_CMD[@]}" --exclude='4/cache/' ~/.config/libreoffice "$BACKUP_DIR/Profils_Lourds/"
run "calibre" "${RSYNC_CMD[@]}" --exclude='caches/' ~/.config/calibre "$BACKUP_DIR/Profils_Lourds/" || true

log ""
log "📖 Sigil..."
run "sigil-ebook" "${RSYNC_CMD[@]}" --exclude='Inspector-Cache/' --exclude='Preview-Cache/' --exclude='local-devtools/' --exclude='local-storage/' --exclude='workspace/' ~/.local/share/sigil-ebook "$BACKUP_DIR/Sigil/" || true

log ""
log "⌨️  GJS OSK..."
run "gnome extensions" "${RSYNC_CMD[@]}" ~/.local/share/gnome-shell/extensions/ "$BACKUP_DIR/GJS_OSK/" || true
dconf dump /org/gnome/shell/extensions/gjsosk/ >"$BACKUP_DIR/GJS_OSK/gjsosk_settings.ini" 2>/dev/null || true

log ""
log "🔐 Secrets..."
run ".ssh" "${RSYNC_CMD[@]}" ~/.ssh "$BACKUP_DIR/Secrets/"
run "rclone.conf" "${RSYNC_CMD[@]}" ~/.config/rclone/rclone.conf "$BACKUP_DIR/Secrets/"
run "samba credentials" sudo "${RSYNC_CMD[@]}" /etc/samba/.credentials "$BACKUP_DIR/Secrets/"
sudo chown -R "$USER:$USER" "$BACKUP_DIR/Secrets/" 2>/dev/null || true

log ""
log "🖱️  Bluetooth..."
run "bluetooth" sudo "${RSYNC_CMD[@]}" /var/lib/bluetooth/ "$BACKUP_DIR/Secrets/bluetooth/"
sudo chown -R "$USER:$USER" "$BACKUP_DIR/Secrets/bluetooth/" 2>/dev/null || true

log ""
log "🖥️  Machine Virtuelle win11..."
NOM_VM="win11"
sudo virsh dumpxml "$NOM_VM" | tee "$BACKUP_DIR/Machines_Virtuelles/${NOM_VM}.xml" >/dev/null
log "  Copie du disque VM en cours..."

# shellcheck disable=SC2024
if sudo "${RSYNC_CMD[@]}" "/var/lib/libvirt/images/${NOM_VM}.qcow2" "$BACKUP_DIR/Machines_Virtuelles/" >>"$LOG_FILE" 2>&1; then
  sudo chown "$USER:$USER" "$BACKUP_DIR/Machines_Virtuelles/${NOM_VM}.qcow2"
  log "  ✅ OK"
else
  log "  ⚠️  Erreurs (voir log)"
fi

log ""
log "======================================"
log "✅ Sauvegarde terminée : $(date '+%d/%m/%Y %H:%M:%S')"
log "📋 Log : $LOG_FILE"
log "======================================"