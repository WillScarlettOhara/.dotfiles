#!/bin/bash

BACKUP_DIR="$HOME/OneDrive/Linux_Backup_2026"
LOG_FILE="$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).log"

RSYNC_CMD=(rsync -auL --delete --info=progress2)


log() {
  printf "%s\n" "$1" | tee -a "$LOG_FILE"
}

run() {
  local label="$1"
  shift
  log "  $label"
  # On utilise 'tee' pour voir l'action en direct dans le terminal tout en gardant le log
  if "$@" 2>&1 | tee -a "$LOG_FILE"; then
    log "  ✅ OK"
  else
    log "  ⚠️  Erreurs (voir log)"
  fi
}

rclone_sync() {
  local label="$1"
  shift
  log "  $label"
  
  # L'explication des options magiques :
  # -P : Ta barre de progression en direct
  # --disable-http2 : Règle le bug de freeze réseau très connu avec OneDrive
  # --timeout 5m : Si Microsoft fait le mort à la fin, on force la fermeture
  # --fast-list : Accélère massivement la lecture/suppression des 9000 fichiers
  
  if rclone sync "$@" -P --log-file="$LOG_FILE" --log-level=INFO --disable-http2 --timeout 5m --fast-list; then
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
log "🦊 Firefox (Force Copy)..."

# 1. Les fichiers de configuration de base
run "firefox profiles.ini" "${RSYNC_CMD[@]}" \
  ~/.config/mozilla/firefox/profiles.ini \
  ~/.config/mozilla/firefox/installs.ini \
  "$BACKUP_DIR/Profils_Lourds/firefox/"

# 2. Le profil actif avec TOUTES tes exclusions
run "firefox profil actif" "${RSYNC_CMD[@]}" \
  --exclude="cache2/" \
  --exclude="Cache/" \
  --exclude="*.sqlite-wal" \
  --exclude="*.sqlite-shm" \
  --exclude="*.sqlite-journal" \
  --exclude="minidumps/" \
  --exclude="crashes/" \
  --exclude="lock" \
  --exclude=".parentlock" \
  --exclude="thumbnails/" \
  --exclude="sessionstore-backups/" \
  --exclude="storage/default/*/cache/**" \
  --exclude="SiteSecurityServiceState.bin" \
  --exclude="AlternateServices.bin" \
  ~/.config/mozilla/firefox/d91w3rmx.default-release-1739246972176/ \
  "$BACKUP_DIR/Profils_Lourds/firefox/d91w3rmx.default-release-1739246972176/"

log ""
log "📧 Thunderbird..."
if pgrep -x thunderbird >/dev/null; then
  log "  ⚠️  Thunderbird est ouvert — sauvegarde ignorée"
else
  run "thunderbird profiles.ini" "${RSYNC_CMD[@]}" \
    ~/.thunderbird/profiles.ini \
    ~/.thunderbird/installs.ini \
    "$BACKUP_DIR/Profils_Lourds/thunderbird/" || true
    
  run "thunderbird profil actif" "${RSYNC_CMD[@]}" \
    --exclude="cache/" \
    --exclude="Cache/" \
    --exclude="lock" \
    --exclude="parent.lock" \
    --exclude="*.sqlite-wal" \
    --exclude="*.sqlite-shm" \
    --exclude="shader-cache/" \
    --exclude="datareporting/" \
    --exclude="saved-telemetry-pings/" \
    --exclude="crashes/" \
    --exclude="minidumps/" \
    --exclude="scheduled-notifications/" \
    --exclude="session.json" \
    --exclude="session.json.backup" \
    --exclude="ImapMail/**" \
    ~/.thunderbird/o2dmdq0v.default-release/ \
    "$BACKUP_DIR/Profils_Lourds/thunderbird/o2dmdq0v.default-release/"
fi

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