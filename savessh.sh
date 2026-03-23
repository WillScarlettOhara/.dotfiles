#!/bin/bash

export NODE_NO_WARNINGS=1

echo "======================================"
echo "🔐 Sauvegarde des clés SSH dans Bitwarden"
echo "======================================"

# 1. Vérification session
if [[ -z "$BW_SESSION" ]]; then
  echo "❌ Vault non déverrouillé."
  echo "   Lance d'abord : export BW_SESSION=\$(bw unlock --raw)"
  exit 1
fi
echo "  ✅ Session active."

# 2. Vérification des clés locales
if [[ ! -f ~/.ssh/id_rsa ]] || [[ ! -f ~/.ssh/id_rsa.pub ]]; then
  echo "❌ Clés SSH introuvables dans ~/.ssh/"
  exit 1
fi

bw sync >/dev/null

# 3. Encodage des clés
echo "📦 Encodage des clés SSH..."
PRIVATE_KEY=$(base64 -w 0 ~/.ssh/id_rsa)
PUBLIC_KEY=$(cat ~/.ssh/id_rsa.pub)

# 4. Création du JSON
JSON=$(bw get template item | jq \
  --arg priv "$PRIVATE_KEY" \
  --arg pub "$PUBLIC_KEY" \
  '.type = 2 |
   .name = "SSH GitHub" |
   .secureNote = {"type": 0} |
   .notes = ("PRIVATE_KEY_B64:\n" + $priv + "\n\nPUBLIC_KEY:\n" + $pub)')

if ! echo "$JSON" | jq . >/dev/null 2>&1; then
  echo "❌ JSON invalide, abandon."
  exit 1
fi

# 5. Envoi à Bitwarden
echo "🚀 Envoi vers Bitwarden..."
if echo "$JSON" | bw encode | bw create item >/dev/null; then
  echo "  ✅ Clés SSH sauvegardées sous 'SSH GitHub' !"
else
  echo "  ❌ Échec de la création de l'item."
  exit 1
fi

# 6. Verrouillage
bw lock >/dev/null
echo "🔒 Vault reverrouillé."
echo ""
echo "Pour restaurer :"
echo "  export BW_SESSION=\$(bw unlock --raw)"
echo "  bw get item 'SSH GitHub' | jq -r '.notes' | grep -A1 'PRIVATE_KEY_B64:' | tail -1 | base64 -d > ~/.ssh/id_rsa"
echo "  bw get item 'SSH GitHub' | jq -r '.notes' | grep -A1 'PUBLIC_KEY:' | tail -1 > ~/.ssh/id_rsa.pub"
echo "  chmod 600 ~/.ssh/id_rsa && chmod 644 ~/.ssh/id_rsa.pub"