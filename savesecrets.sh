#!/bin/bash
export NODE_NO_WARNINGS=1

echo "======================================"
echo "🔐 Synchronisation des Secrets vers Bitwarden"
echo "======================================"

# 1. Vérification et Déverrouillage
BW_STATUS=$(bw status | jq -r '.status' 2>/dev/null || echo "error")
if [[ "$BW_STATUS" == "unauthenticated" ]]; then
  echo "🔑 Connexion à Bitwarden..." >/dev/tty
  bw login </dev/tty
  BW_STATUS=$(bw status | jq -r '.status')
fi

if [[ "$BW_STATUS" == "locked" ]]; then
  echo -n "🔓 Vault verrouillé. Entrez votre mot de passe maître : " >/dev/tty
  read -s -r BW_PASS </dev/tty
  echo "" >/dev/tty
  export BW_PASS
  export BW_SESSION
  BW_SESSION=$(bw unlock --raw --passwordenv BW_PASS)
  unset BW_PASS
fi

if [[ -z "$BW_SESSION" ]]; then
  echo "❌ Échec du déverrouillage (mot de passe incorrect)."
  exit 1
fi
echo "  ✅ Mot de passe correct, vault déverrouillé."
bw sync >/dev/null

# --- FONCTION : CLÉ SSH NATIVE (TYPE 5) ---
sync_ssh() {
  local name="$1"
  echo "  🔍 Vérification de l'existence de '$name' sur Bitwarden..."
  local item_id
  item_id=$(bw list items --search "$name" 2>/dev/null | jq -r ".[] | select(.name == \"$name\") | .id" | head -n 1)

  if [[ -n "$item_id" ]]; then
    echo "  ⏭️  '$name' existe déjà. (Ignoré)"
  else
    echo "  ➕ Création de '$name' (Format Clé SSH natif)..."
    # Lecture en texte brut (pas de base64 nécessaire pour le type natif)
    local priv
    priv=$(cat ~/.ssh/id_rsa)
    local pub
    pub=$(cat ~/.ssh/id_rsa.pub)
    # Calcul de l'empreinte exigée par Bitwarden
    local fp
    fp=$(ssh-keygen -lf ~/.ssh/id_rsa.pub | awk '{print $2}')

    local json
    json=$(bw get template item | jq --arg priv "$priv" --arg pub "$pub" --arg fp "$fp" --arg name "$name" \
      '.type = 5 | .name = $name | .sshKey = {"privateKey": $priv, "publicKey": $pub, "keyFingerprint": $fp}')
    echo "$json" | bw encode | bw create item >/dev/null
    echo "  ✅ Créé avec succès : $name"
  fi
}

# --- FONCTION : NOTE SÉCURISÉE (TYPE 2) ---
sync_note() {
  local name="$1"
  local content="$2"
  echo "  🔍 Vérification de l'existence de '$name' sur Bitwarden..."
  local item_id
  item_id=$(bw list items --search "$name" 2>/dev/null | jq -r ".[] | select(.name == \"$name\") | .id" | head -n 1)

  if [[ -n "$item_id" ]]; then
    echo "  ⏭️  '$name' existe déjà. (Ignoré)"
  else
    echo "  ➕ Création de '$name'..."
    local json
    json=$(bw get template item | jq --arg notes "$content" --arg name "$name" \
      '.type = 2 | .name = $name | .secureNote = {"type": 0} | .notes = $notes')
    echo "$json" | bw encode | bw create item >/dev/null
    echo "  ✅ Créé avec succès : $name"
  fi
}

# 2. Synchronisation
if [[ -f ~/.ssh/id_rsa ]] && [[ -f ~/.ssh/id_rsa.pub ]]; then
  sync_ssh "SSH GitHub"
fi

if [[ -f ~/.config/rclone/rclone.conf ]]; then
  sync_note "Config Rclone" "$(cat ~/.config/rclone/rclone.conf)"
fi

if [[ -f /etc/samba/.credentials ]]; then
  # shellcheck disable=SC2024  # redirects to /dev/tty are intentional here
  sudo -v </dev/tty >/dev/tty 2>&1
  sync_note "Samba Credentials" "$(sudo sh -c 'cat /etc/samba/.credentials')"
fi

FSTAB_CONTENT="UUID=REDACTED  /mnt/2TB  ntfs3  uid=1000,gid=1000,dmask=022,fmask=133,auto,nofail  0  0
UUID=REDACTED  /mnt/1TB  ntfs3  uid=1000,gid=1000,dmask=022,fmask=133,auto,nofail  0  0
//REDACTED/data /mnt/samba/data cifs credentials=/etc/samba/.credentials,uid=1000,gid=1000,file_mode=0777,dir_mode=0777,nobrl,noperm,noserverino,cache=none,iocharset=utf8,nofail 0 0"
sync_note "Fstab Mounts" "$FSTAB_CONTENT"

# 3. Verrouillage
bw lock >/dev/null
echo "🔒 Vault reverrouillé."
