#!/bin/bash
# save.sh — Sauvegarde unifiée : GitHub (dotfiles) + Bitwarden (secrets) + Restic/OneDrive (données)

set -e
export NODE_NO_WARNINGS=1

BACKUP_DIR="$HOME/OneDrive/Backup_PC"
export RESTIC_REPOSITORY="$BACKUP_DIR/restic-repo"
LOG_FILE="$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).log"

log() { printf "%s\n" "$1" | tee -a "$LOG_FILE"; }

mkdir -p "$BACKUP_DIR"
log "======================================"
log "🚀 Sauvegarde : $(date '+%d/%m/%Y %H:%M:%S')"
log "======================================"

# ─── 0. Prérequis ───────────────────────────────────────────────────────────
if ! command -v restic &>/dev/null || ! command -v jq &>/dev/null; then
  log "📦 Installation des outils manquants..."
  if command -v paru &>/dev/null; then
    paru -S --noconfirm --needed restic jq >/dev/null
  else
    sudo pacman -S --noconfirm --needed restic jq >/dev/null
  fi
fi

# ─── 1. Bitwarden — mot de passe Restic ─────────────────────────────────────
log ""
log "🔐 Récupération du mot de passe Restic depuis Bitwarden..."

BW_STATUS=$(bw status | jq -r '.status' 2>/dev/null || echo "error")
if [ "$BW_STATUS" = "unauthenticated" ]; then
  bw login </dev/tty
  BW_STATUS=$(bw status | jq -r '.status' 2>/dev/null)
fi
if [ "$BW_STATUS" = "locked" ]; then
  echo -n "🔓 Mot de passe maître : " >/dev/tty
  read -s -r BW_PASS </dev/tty
  echo "" >/dev/tty
  export BW_PASS BW_SESSION
  BW_SESSION=$(bw unlock --raw --passwordenv BW_PASS)
  unset BW_PASS
fi

bw sync --session "$BW_SESSION" >/dev/null 2>&1

export RESTIC_PASSWORD
RESTIC_PASSWORD=$(bw list items --search "Restic Password" --session "$BW_SESSION" 2>/dev/null |
  jq -r '.[] | select(.name == "Restic Password") | (.notes // .login.password // empty)')

if [ -z "$RESTIC_PASSWORD" ]; then
  log "❌ Mot de passe Restic introuvable dans Bitwarden."
  exit 1
fi
log "  ✅ Mot de passe Restic récupéré."

# Initialise le repo si nécessaire
if ! restic snapshots &>/dev/null; then
  log "🆕 Initialisation du dépôt Restic..."
  restic init
fi

# ─── 2. GitHub — Dotfiles ───────────────────────────────────────────────────
log ""
log "🐙 Sauvegarde GitHub des dotfiles..."

# Capture des configs qui ne sont pas dans le repo (générées dynamiquement)
sudo cp /etc/systemd/system/*.mount "$HOME/.dotfiles/system-mounts/" 2>/dev/null || true

IS_GNOME=false
[[ "${XDG_CURRENT_DESKTOP^^}" == *"GNOME"* ]] && IS_GNOME=true

if [ "$IS_GNOME" = true ]; then
  mkdir -p "$HOME/.dotfiles/gnome"
  dconf dump /org/gnome/shell/extensions/gjsosk/ \
    >"$HOME/.dotfiles/gnome/gjsosk_settings.ini" 2>/dev/null || true
  dconf dump /org/gnome/shell/extensions/dash-to-panel/ \
    >"$HOME/.dotfiles/gnome/dash-to-panel_settings.ini" 2>/dev/null || true
  dconf dump /org/gnome/shell/extensions/arcmenu/ \
    >"$HOME/.dotfiles/gnome/arcmenu_settings.ini" 2>/dev/null || true
  dconf dump /org/gnome/shell/extensions/vitals/ \
    >"$HOME/.dotfiles/gnome/vitals_settings.ini" 2>/dev/null || true
fi

if [ -z "$(git -C "$HOME/.dotfiles" status --porcelain)" ]; then
  log "  ✅ Aucun changement dans les dotfiles."
else
  git -C "$HOME/.dotfiles" add .
  if git -C "$HOME/.dotfiles" \
    commit -m "Auto Backup: $(date '+%Y-%m-%d %H:%M')" >/dev/null 2>&1; then
    if git -C "$HOME/.dotfiles" push -q origin master; then
      log "  ✅ Dotfiles pushés sur GitHub."
    else
      log "  ⚠️  Push GitHub échoué (clés SSH ?)."
    fi
  else
    log "  ⚠️  Commit échoué (identité git configurée ?)."
  fi
fi

# ─── 3. Bitwarden — Secrets (SSH + rclone) ──────────────────────────────────
log ""
log "🔑 Synchronisation des secrets vers Bitwarden..."
if [ -f "$HOME/.dotfiles/savesecrets.sh" ]; then
  bash "$HOME/.dotfiles/savesecrets.sh" | tee -a "$LOG_FILE"
else
  log "  ⚠️  savesecrets.sh introuvable."
fi

# ─── 4. Exclusions Restic ───────────────────────────────────────────────────
EXCLUDES_FILE="/tmp/restic_excludes.txt"
cat >"$EXCLUDES_FILE" <<'EOF'
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
caches
Preview-Cache
EOF

# ─── 5. Restic — Profils utilisateur ────────────────────────────────────────
log ""
log "📦 Sauvegarde des profils utilisateurs..."

USER_TARGETS=(
  "$HOME/.config/mozilla/firefox"
  "$HOME/.config/libreoffice"
  "$HOME/.config/calibre"
  "$HOME/.local/share/sigil-ebook"
  "$HOME/.config/sunshine"
  "$HOME/.config/lg-buddy"
  "$HOME/.ssh/known_hosts"
)

if pgrep -x thunderbird >/dev/null; then
  log "  ⚠️  Thunderbird ouvert — ignoré."
else
  USER_TARGETS+=("$HOME/.thunderbird")
fi

if restic backup "${USER_TARGETS[@]}" \
  --exclude-file="$EXCLUDES_FILE" >>"$LOG_FILE" 2>&1; then
  log "  ✅ Profils utilisateurs sauvegardés."
else
  log "  ⚠️  Erreurs restic profils (voir log)."
fi

# ─── 6. Restic — Fichiers système (root) ────────────────────────────────────
log ""
log "🔒 Sauvegarde des fichiers système sensibles..."

# Dump XML de la VM
NOM_VM="win11"
VM_XML="/tmp/${NOM_VM}.xml"
sudo virsh dumpxml "$NOM_VM" 2>/dev/null | tee "$VM_XML" >/dev/null || true

set +e
sudo --preserve-env=RESTIC_REPOSITORY,RESTIC_PASSWORD restic backup \
  "/var/lib/bluetooth" \
  "/etc/samba" \
  "/etc/fstab" \
  "/var/lib/libvirt/images/${NOM_VM}.qcow2" \
  "$VM_XML" \
  2>&1 | tee -a "$LOG_FILE" >/dev/null
SYS_STATUS=${PIPESTATUS[0]}
set -e

rm -f "$EXCLUDES_FILE" "$VM_XML"

if [ "$SYS_STATUS" -eq 0 ]; then
  log "  ✅ Fichiers système sauvegardés."
else
  log "  ⚠️  Erreurs restic système (voir log)."
fi

# ─── 7. Nettoyage snapshots (garder les 10 derniers) ────────────────────────
log ""
log "🧹 Nettoyage des anciens snapshots..."
restic forget --keep-last 10 --prune >>"$LOG_FILE" 2>&1 || true

log ""
log "======================================"
log "✅ Sauvegarde terminée !"
log "📊 Snapshots : restic snapshots"
log "📋 Log : $LOG_FILE"
log "======================================"
