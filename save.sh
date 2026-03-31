#!/bin/bash
# save.sh - Sauvegarde unifiée vers Restic (OneDrive) + GitHub + Bitwarden

set -e

BACKUP_DIR="$HOME/OneDrive/Backup_PC"
LOG_FILE="$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).log"

# Restic Repository
export RESTIC_REPOSITORY="$BACKUP_DIR/restic-repo"

log() {
  printf "%s\n" "$1" | tee -a "$LOG_FILE"
}

mkdir -p "$BACKUP_DIR"

log "======================================"
log "🚀 Démarrage de la sauvegarde : $(date '+%d/%m/%Y %H:%M:%S')"
log "======================================"

# ─── 0. Préparation de Restic ──────────────────────────────────────────────────
log ""
log "🔐 Récupération du mot de passe Restic depuis Bitwarden..."
BW_STATUS=$(bw status | jq -r '.status' 2>/dev/null || echo "error")
if [ "$BW_STATUS" = "locked" ] || [ "$BW_STATUS" = "unauthenticated" ]; then
  log "⚠️  Bitwarden est verrouillé. Veuillez le déverrouiller :"
  export BW_SESSION
  BW_SESSION=$(bw unlock --raw)
fi

export RESTIC_PASSWORD
RESTIC_PASSWORD=$(bw get item "Restic Password" | jq -r '.notes // empty')

if [ -z "$RESTIC_PASSWORD" ]; then
  log "❌ Erreur : Mot de passe Restic introuvable !"
  exit 1
fi

if ! restic snapshots >/dev/null 2>&1; then
  log "🆕 Initialisation du dépôt Restic dans $RESTIC_REPOSITORY..."
  restic init
fi

# ─── 1. GitHub (Dotfiles Automatiques) ─────────────────────────────────────────
log ""
log "🐙 Sauvegarde GitHub des Dotfiles..."

sudo cp /etc/systemd/system/*.mount "$HOME/.dotfiles/system-mounts/" 2>/dev/null || true
dconf dump /org/gnome/shell/extensions/gjsosk/ >"$HOME/.dotfiles/gnome/gjsosk_settings.ini" 2>/dev/null || true

if git -C "$HOME/.dotfiles" diff --quiet && git -C "$HOME/.dotfiles" diff --cached --quiet && git -C "$HOME/.dotfiles" ls-files --others --exclude-standard | grep -q '^'; then
  log "  ✅ Aucun changement détecté"
else
  git -C "$HOME/.dotfiles" add .
  git -C "$HOME/.dotfiles" commit -m "Auto Backup: $(date '+%Y-%m-%d %H:%M')" >/dev/null
  if git -C "$HOME/.dotfiles" push -q origin master; then
    log "  ✅ Changements pushés sur GitHub"
  else
    log "  ⚠️  Erreur lors du push GitHub"
  fi
fi

# ─── 2. Bitwarden (Les Secrets) ────────────────────────────────────────────────
log ""
bash "$HOME/.dotfiles/savesecrets.sh" | tee -a "$LOG_FILE"

# ─── 3. Création des exclusions Restic ─────────────────────────────────────────
EXCLUDES_FILE="/tmp/restic_excludes.txt"
cat <<EOF >"$EXCLUDES_FILE"
cache2
Cache
cache
*.sqlite-wal
*.sqlite-shm
*.sqlite-journal
minidumps
crashes
lock
.parentlock
parent.lock
thumbnails
sessionstore-backups
SiteSecurityServiceState.bin
AlternateServices.bin
shader-cache
datareporting
saved-telemetry-pings
scheduled-notifications
session.json
session.json.backup
ImapMail
4/cache
caches
Preview-Cache
EOF

# ─── 4. Restic (Sauvegarde Volumétrie Utilisateur) ─────────────────────────────
log ""
log "📦 Sauvegarde des profils utilisateurs (Firefox, Thunderbird, Apps)..."

USER_TARGETS=(
  "$HOME/.config/mozilla/firefox"
  "$HOME/.config/libreoffice"
  "$HOME/.config/calibre"
  "$HOME/.local/share/sigil-ebook"
  "$HOME/.config/sunshine"
)

if pgrep -x thunderbird >/dev/null; then
  log "  ⚠️  Thunderbird est ouvert — ignoré de la sauvegarde"
else
  USER_TARGETS+=("$HOME/.thunderbird")
fi

if restic backup "${USER_TARGETS[@]}" --exclude-file="$EXCLUDES_FILE" >>"$LOG_FILE" 2>&1; then
  log "  ✅ Données Utilisateurs sauvegardées (Dédupliquées !)"
else
  log "  ⚠️  Erreurs Restic (voir log)"
fi

# ─── 5. Restic (Sauvegarde Machine Virtuelle - ROOT) ───────────────────────────
log ""
log "🖥️  Sauvegarde de la Machine Virtuelle win11..."
NOM_VM="win11"
VM_XML="/tmp/${NOM_VM}.xml"

sudo virsh dumpxml "$NOM_VM" 2>/dev/null | tee "$VM_XML" >/dev/null || true

log "  Copie incrémentale du disque qcow2 (Déduplication Restic)..."

set +e

sudo --preserve-env=RESTIC_REPOSITORY,RESTIC_PASSWORD restic backup \
  "/var/lib/libvirt/images/${NOM_VM}.qcow2" \
  "$VM_XML" 2>&1 | tee -a "$LOG_FILE" >/dev/null

VM_BKP_STATUS=${PIPESTATUS[0]}

set -e

if [ "$VM_BKP_STATUS" -eq 0 ]; then
  log "  ✅ VM Sauvegardée"
else
  log "  ⚠️  Erreurs sur la VM (voir log)"
fi

rm -f "$EXCLUDES_FILE" "$VM_XML"

log ""
log "======================================"
log "✅ Toutes les sauvegardes (Git, BW, Restic/OneDrive) sont terminées !"
log "📊 Pour voir les snapshots Restic : restic snapshots"
log "📋 Log détaillé : $LOG_FILE"
log "======================================"
