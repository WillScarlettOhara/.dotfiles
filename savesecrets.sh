#!/bin/bash
# savesecrets.sh — Synchronise UNIQUEMENT les secrets irremplaçables vers Bitwarden
# Règle : Bitwarden = ce qui est nécessaire AVANT que OneDrive/Restic soit disponible
#   → Clé SSH (pour cloner les dotfiles)
#   → rclone.conf (token OAuth pour monter OneDrive)
#   → Mot de passe Restic (pour déchiffrer les backups)
# Tout le reste (samba, fstab, bluetooth...) est géré par Restic.

export NODE_NO_WARNINGS=1

echo "======================================"
echo "🔐 Synchronisation des secrets vers Bitwarden"
echo "======================================"

# ─── Déverrouillage ─────────────────────────────────────────────────────────
BW_STATUS=$(bw status | jq -r '.status' 2>/dev/null || echo "error")

if [ "$BW_STATUS" = "unauthenticated" ]; then
  echo "🔑 Connexion à Bitwarden..." >/dev/tty
  bw login </dev/tty
  BW_STATUS=$(bw status | jq -r '.status')
fi

if [ "$BW_STATUS" = "locked" ]; then
  echo -n "🔓 Mot de passe maître : " >/dev/tty
  read -s -r BW_PASS </dev/tty
  echo "" >/dev/tty
  export BW_PASS BW_SESSION
  BW_SESSION=$(bw unlock --raw --passwordenv BW_PASS)
  unset BW_PASS
fi

if [ -z "$BW_SESSION" ]; then
  echo "❌ Échec du déverrouillage."
  exit 1
fi
echo "  ✅ Vault déverrouillé."
bw sync >/dev/null 2>&1

# ─── Helpers ────────────────────────────────────────────────────────────────

# Crée un item s'il n'existe pas encore (jamais d'écrasement automatique)
_item_exists() {
  local name="$1"
  bw list items --search "$name" 2>/dev/null | \
    jq -e ".[] | select(.name == \"$name\")" >/dev/null 2>&1
}

sync_ssh_key() {
  local name="$1"
  echo ""
  echo "  🗝️  Clé SSH '$name'..."
  if _item_exists "$name"; then
    echo "  ⏭️  Existe déjà dans Bitwarden. Ignoré."
    return
  fi
  local priv pub fp
  priv=$(cat ~/.ssh/id_rsa)
  pub=$(cat ~/.ssh/id_rsa.pub)
  fp=$(ssh-keygen -lf ~/.ssh/id_rsa.pub | awk '{print $2}')
  bw get template item | \
    jq --arg priv "$priv" --arg pub "$pub" --arg fp "$fp" --arg name "$name" \
      '.type = 5 | .name = $name | .sshKey = {
        "privateKey": $priv,
        "publicKey": $pub,
        "keyFingerprint": $fp
      }' | \
    bw encode | bw create item --session "$BW_SESSION" >/dev/null
  echo "  ✅ Clé SSH créée : $name"
}

sync_secure_note() {
  local name="$1"
  local content="$2"
  echo ""
  echo "  📝 Note '$name'..."
  if _item_exists "$name"; then
    # Met à jour le contenu si l'item existe
    local item_id
    item_id=$(bw list items --search "$name" 2>/dev/null | \
      jq -r ".[] | select(.name == \"$name\") | .id" | head -n1)
    bw get item "$item_id" --session "$BW_SESSION" | \
      jq --arg notes "$content" '.notes = $notes' | \
      bw encode | bw edit item "$item_id" --session "$BW_SESSION" >/dev/null
    echo "  ✅ Mise à jour : $name"
  else
    bw get template item | \
      jq --arg notes "$content" --arg name "$name" \
        '.type = 2 | .name = $name | .secureNote = {"type": 0} | .notes = $notes' | \
      bw encode | bw create item --session "$BW_SESSION" >/dev/null
    echo "  ✅ Créé : $name"
  fi
}

# ─── Synchronisation ────────────────────────────────────────────────────────

# 1. Clé SSH — nécessaire pour git clone au bootstrap
if [ -f ~/.ssh/id_rsa ] && [ -f ~/.ssh/id_rsa.pub ]; then
  sync_ssh_key "SSH GitHub"
else
  echo "  ⚠️  ~/.ssh/id_rsa introuvable. Ignoré."
fi

# 2. Config rclone — nécessaire pour monter OneDrive avant restic
if [ -f ~/.config/rclone/rclone.conf ]; then
  sync_secure_note "Config Rclone" "$(cat ~/.config/rclone/rclone.conf)"
else
  echo "  ⚠️  ~/.config/rclone/rclone.conf introuvable. Ignoré."
fi

# 3. OpenCode Auth — tokens Copilot, API keys
if [ -f ~/.local/share/opencode/auth.json ]; then
  sync_secure_note "OpenCode Auth" "$(cat ~/.local/share/opencode/auth.json)"
else
  echo "  ⚠️  ~/.local/share/opencode/auth.json introuvable. Ignoré."
fi

# Note : Le mot de passe Restic doit être créé MANUELLEMENT dans Bitwarden
# sous le nom "Restic Password" (notes ou login.password).
# Il n'est jamais généré ici pour éviter de l'écraser accidentellement.

# ─── Verrouillage ───────────────────────────────────────────────────────────
bw lock >/dev/null 2>&1
echo ""
echo "🔒 Vault reverrouillé."
echo "======================================"
echo "✅ Secrets synchronisés."
echo "======================================"
