#!/bin/bash
export NODE_NO_WARNINGS=1

echo "======================================"
echo "🔐 Synchronisation des Secrets vers Bitwarden"
echo "======================================"

# 1. Vérification et Déverrouillage
BW_STATUS=$(bw status | jq -r '.status' 2>/dev/null || echo "error")
if [[ "$BW_STATUS" == "unauthenticated" ]]; then
  echo "🔑 Connexion à Bitwarden..."
  bw login
  BW_STATUS=$(bw status | jq -r '.status')
fi

if [[ "$BW_STATUS" == "locked" ]]; then
  echo -n "🔓 Vault verrouillé. Entrez votre mot de passe maître : "
  read -s -r BW_PASS
  echo ""
  export BW_PASS
  export BW_SESSION=$(bw unlock --raw --passwordenv BW_PASS)
  unset BW_PASS
fi

if [[ -z "$BW_SESSION" ]]; then
  echo "❌ Échec du déverrouillage."
  exit 1
fi
bw sync >/dev/null

# --- FONCTION MAGIQUE : CREATE OU UPDATE ---
upsert_note() {
  local name="$1"
  local content="$2"

  # Cherche si une note avec ce nom exact existe déjà
  local item_id=$(bw list items --search "$name" 2>/dev/null | jq -r ".[] | select(.name == \"$name\") | .id" | head -n 1)

  if [[ -z "$item_id" ]]; then
    # CRÉATION
    local json=$(bw get template item | jq --arg notes "$content" --arg name "$name" \
      '.type = 2 | .name = $name | .secureNote = {"type": 0} | .notes = $notes')
    echo "$json" | bw encode | bw create item >/dev/null
    echo "  ✅ Créé : $name"
  else
    # MISE À JOUR
    local json=$(bw get item "$item_id" | jq --arg notes "$content" '.notes = $notes')
    echo "$json" | bw encode | bw edit item "$item_id" >/dev/null
    echo "  🔄 Mis à jour : $name"
  fi
}

# 2. Sauvegarde des Clés SSH
if [[ -f ~/.ssh/id_rsa ]] && [[ -f ~/.ssh/id_rsa.pub ]]; then
  PRIV=$(base64 -w 0 ~/.ssh/id_rsa)
  PUB=$(cat ~/.ssh/id_rsa.pub)
  SSH_CONTENT="PRIVATE_KEY_B64:
$PRIV

PUBLIC_KEY:
$PUB"
  upsert_note "SSH GitHub" "$SSH_CONTENT"
fi

# 3. Sauvegarde de rclone.conf
if [[ -f ~/.config/rclone/rclone.conf ]]; then
  upsert_note "Config Rclone" "$(cat ~/.config/rclone/rclone.conf)"
fi

# 4. Sauvegarde Samba Credentials
if [[ -f /etc/samba/.credentials ]]; then
  upsert_note "Samba Credentials" "$(sudo cat /etc/samba/.credentials)"
fi

# 5. Sauvegarde des lignes fstab (NTFS / Samba)
FSTAB_CONTENT="UUID=REDACTED  /mnt/2TB  ntfs3  uid=1000,gid=1000,dmask=022,fmask=133,auto,nofail  0  0
UUID=REDACTED  /mnt/1TB  ntfs3  uid=1000,gid=1000,dmask=022,fmask=133,auto,nofail  0  0
//REDACTED/data /mnt/samba/data cifs credentials=/etc/samba/.credentials,uid=1000,gid=1000,file_mode=0777,dir_mode=0777,nobrl,noperm,noserverino,cache=none,iocharset=utf8,nofail 0 0"

upsert_note "Fstab Mounts" "$FSTAB_CONTENT"

# 6. Verrouillage
bw lock >/dev/null
echo "🔒 Vault reverrouillé."
