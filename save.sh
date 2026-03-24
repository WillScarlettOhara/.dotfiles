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
  if "$@" 2>&1 | tee -a "$LOG_FILE" | grep -q "rsync error"; then
    log "  ⚠️  Erreurs (voir log)"
  else
    log "  ✅ OK"
  fi
}

mkdir -p "$BACKUP_DIR"/{Scripts_et_Raccourcis,Services_Systemd/User,Services_Systemd/System,Profils_Lourds,Sigil,GJS_OSK,Machines_Virtuelles}

log "======================================"
log "🚀 Démarrage de la sauvegarde : $(date '+%d/%m/%Y %H:%M:%S')"
log "======================================"

# ─── 1. GitHub (Dotfiles Automatiques) ──────────────────────────────────────────
log ""
log "🐙 Sauvegarde GitHub des Dotfiles..."
if git -C "$HOME/.dotfiles" diff --quiet && git -C "$HOME/.dotfiles" diff --cached --quiet; then
  log "  ✅ Aucun changement détecté"
else
  git -C "$HOME/.dotfiles" add .
  git -C "$HOME/.dotfiles" commit -m "Auto Backup: $(date '+%Y-%m-%d %H:%M')" >/dev/null
  git -C "$HOME/.dotfiles" push -q origin main
  log "  ✅ Changements pushés sur GitHub"
fi

# ─── 2. Bitwarden (Les Secrets) ────────────────────────────────────────────────
log ""
# Appelle ton script Bitwarden pour mettre à jour les notes
bash "$HOME/.dotfiles/savesecrets.sh" | tee -a "$LOG_FILE"

# ─── 3. OneDrive (La Volumétrie) ───────────────────────────────────────────────
log ""
log "☁️  Sauvegarde OneDrive (Scripts & Raccourcis)..."
run "$HOME/.local/bin" "${RSYNC_CMD[@]}" ~/.local/bin/ "$BACKUP_DIR/Scripts_et_Raccourcis/bin/"
run "$HOME/.local/share/applications" "${RSYNC_CMD[@]}" ~/.local/share/applications/ "$BACKUP_DIR/Scripts_et_Raccourcis/applications/"

log ""
log "🔄 Services Systemd..."
run "systemd/user" "${RSYNC_CMD[@]}" ~/.config/systemd/user/ "$BACKUP_DIR/Services_Systemd/User/"
run "systemd/system *.mount" sudo "${RSYNC_CMD[@]}" /etc/systemd/system/*.mount "$BACKUP_DIR/Services_Systemd/System/"
sudo chown -R "$USER:$USER" "$BACKUP_DIR/Services_Systemd/System/" 2>/dev/null || true

log ""
log "🦊 Firefox..."
run "firefox profiles.ini" "${RSYNC_CMD[@]}" ~/.config/mozilla/firefox/profiles.ini ~/.config/mozilla/firefox/installs.ini "$BACKUP_DIR/Profils_Lourds/firefox/"
run "firefox profil actif" "${RSYNC_CMD[@]}" \
  --exclude="cache2/" --exclude="Cache/" --exclude="*.sqlite-wal" --exclude="*.sqlite-shm" \
  --exclude="thumbnails/" --exclude="sessionstore-backups/" \
  ~/.config/mozilla/firefox/d91w3rmx.default-release-1739246972176/ "$BACKUP_DIR/Profils_Lourds/firefox/d91w3rmx.default-release-1739246972176/"

log ""
log "📧 Thunderbird..."
run "thunderbird profiles.ini" "${RSYNC_CMD[@]}" ~/.thunderbird/profiles.ini ~/.thunderbird/installs.ini "$BACKUP_DIR/Profils_Lourds/thunderbird/" || true
run "thunderbird profil actif" "${RSYNC_CMD[@]}" \
  --exclude="cache/" --exclude="Cache/" --exclude="*.sqlite-wal" --exclude="*.sqlite-shm" \
  --exclude="ImapMail/**" \
  ~/.thunderbird/o2dmdq0v.default-release/ "$BACKUP_DIR/Profils_Lourds/thunderbird/o2dmdq0v.default-release/"

log ""
log "📚 Autres apps (LibreOffice, Calibre, Sigil, GJS OSK)..."
run "libreoffice" "${RSYNC_CMD[@]}" --exclude='4/cache/' ~/.config/libreoffice "$BACKUP_DIR/Profils_Lourds/"
run "calibre" "${RSYNC_CMD[@]}" --exclude='caches/' ~/.config/calibre "$BACKUP_DIR/Profils_Lourds/" || true
run "sigil-ebook" "${RSYNC_CMD[@]}" --exclude='Preview-Cache/' ~/.local/share/sigil-ebook "$BACKUP_DIR/Sigil/" || true
run "gjs osk" "${RSYNC_CMD[@]}" ~/.local/share/gnome-shell/extensions/ "$BACKUP_DIR/GJS_OSK/" || true
dconf dump /org/gnome/shell/extensions/gjsosk/ >"$BACKUP_DIR/GJS_OSK/gjsosk_settings.ini" 2>/dev/null || true

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
log "✅ Toutes les sauvegardes (Git, BW, OneDrive) sont terminées !"
log "📋 Log : $LOG_FILE"
log "======================================"

