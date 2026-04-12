#!/bin/bash
# lib/common.sh — Shared functions for bootstrap.sh & save.sh

export NODE_NO_WARNINGS=1

# ─── Logging ──────────────────────────────────────────────────────────────────

LOG_FILE="${LOG_FILE:-/dev/null}"

log() {
  local level="${2:-INFO}"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  printf "[%s] [%s] %s\n" "$timestamp" "$level" "$1" | tee -a "$LOG_FILE"
}

log_warn()  { log "$1" "WARN"; }
log_error() { log "$1" "ERROR"; }

# ─── Desktop Environment Detection ────────────────────────────────────────────

detect_de() {
  IS_GNOME=false
  if [[ "${XDG_CURRENT_DESKTOP^^}" == *"GNOME"* ]]; then
    IS_GNOME=true
    log "🖥️  Environnement GNOME détecté."
  fi
}

# ─── Bitwarden Login + Unlock ─────────────────────────────────────────────────
# Handles the full auth lifecycle: unauthenticated → locked → unlocked
# Uses --passwordfile + shred instead of --passwordenv for security
# Always passes --session "$BW_SESSION" to subsequent bw commands

bw_login_unlock() {
  local pass_file
  pass_file=$(mktemp /tmp/bw_pass.XXXXXX)
  chmod 600 "$pass_file"

  # Ensure cleanup on any exit path from this function
  trap 'shred -u "$pass_file" 2>/dev/null; trap - RETURN' RETURN

  local status
  status=$(bw status 2>/dev/null | jq -r '.status' 2>/dev/null || echo "error")

  if [ "$status" = "unauthenticated" ]; then
    log "🔑 Bitwarden non authentifié — login requis..."
    bw login </dev/tty
    status=$(bw status 2>/dev/null | jq -r '.status' 2>/dev/null || echo "error")
  fi

  if [ "$status" = "locked" ]; then
    echo -n "🔓 Mot de passe maître Bitwarden : " >/dev/tty
    local bw_pass
    read -s -r bw_pass </dev/tty
    echo "" >/dev/tty

    echo "$bw_pass" > "$pass_file"
    unset bw_pass

    BW_SESSION=$(bw unlock --raw --passwordfile "$pass_file" 2>/dev/null)
    export BW_SESSION
  fi

  if [ -z "${BW_SESSION:-}" ]; then
    log_error "Échec du déverrouillage Bitwarden."
    exit 1
  fi

  bw sync --session "$BW_SESSION" >/dev/null 2>&1
  log "✅ Bitwarden déverrouillé et synchronisé."
}

# ─── Generic: wait for directory with timeout ─────────────────────────────────

wait_for_dir() {
  local dir="$1"
  local timeout="${2:-60}"
  local elapsed=0

  while [ ! -d "$dir" ] && [ "$elapsed" -lt "$timeout" ]; do
    sleep 2
    elapsed=$((elapsed + 2))
    echo -n "."
  done
  echo ""

  if [ ! -d "$dir" ]; then
    log_error "$dir non disponible après ${timeout}s."
    return 1
  fi
  return 0
}

# ─── Generic: install packages via paru or pacman ─────────────────────────────

install_packages() {
  local pkgs=("$@")

  if command -v paru &>/dev/null; then
    paru -S --needed --noconfirm "${pkgs[@]}"
  else
    sudo pacman -S --needed --noconfirm "${pkgs[@]}"
  fi
}