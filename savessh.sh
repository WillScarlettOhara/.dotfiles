#!/bin/bash
export NODE_NO_WARNINGS=1

echo "======================================"
echo "🔐 Sauvegarde des clés SSH dans Bitwarden"
echo "======================================"

# 1. Vérifier si on est bien connecté au compte
BW_STATUS=$(bw status | jq -r '.status' 2>/dev/null || echo "error")

if [[ "$BW_STATUS" == "unauthenticated" ]]; then
  echo "🔑 Vous n'êtes pas connecté à Bitwarden. Veuillez vous connecter :"
  bw login
  BW_STATUS=$(bw status | jq -r '.status')
fi

# 2. Déverrouillage blindé (Bypass total du prompt Node.js)
if [[ "$BW_STATUS" == "locked" ]]; then
  echo -n "🔓 Vault verrouillé. Entrez votre mot de passe maître : "
  read -s -r BW_PASS
  echo ""

  export BW_PASS
  # On utilise --passwordenv pour que Bitwarden ne pose aucune question !
  export BW_SESSION=$(bw unlock --raw --passwordenv BW_PASS)

  # Sécurité absolue : on détruit le mot de passe en clair immédiatement
  unset BW_PASS
fi

# 3. Vérification de la session
if [[ -z "$BW_SESSION" ]]; then
  echo "❌ Échec du déverrouillage (mot de passe incorrect ou plantage)."
  exit 1
fi
echo "  ✅ Vault déverrouillé avec succès."

# 4. Vérification des clés locales
if [[ ! -f ~/.ssh/id_rsa ]] || [[ ! -f ~/.ssh/id_rsa.pub ]]; then
  echo "❌ Clés SSH introuvables dans ~/.ssh/"
  exit 1
fi

bw sync >/dev/null

# 5. Encodage des clés (base64 -w 0 est parfait ici !)
echo "📦 Encodage des clés SSH..."
PRIVATE_KEY=$(base64 -w 0 ~/.ssh/id_rsa)
PUBLIC_KEY=$(cat ~/.ssh/id_rsa.pub)

# 6. Création du JSON (Type 2 = Note sécurisée)
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

# 7. Envoi à Bitwarden
echo "🚀 Envoi vers Bitwarden..."
if echo "$JSON" | bw encode | bw create item >/dev/null; then
  echo "  ✅ Clés SSH sauvegardées sous 'SSH GitHub' !"
else
  echo "  ❌ Échec de la création de l'item."
  exit 1
fi

# 8. Verrouillage final
bw lock >/dev/null
echo "🔒 Vault reverrouillé."
echo ""
echo "💡 Pour restaurer plus tard :"
echo "  export BW_SESSION=\$(bw unlock --raw)"
echo "  bw get item 'SSH GitHub' | jq -r '.notes' | grep -A1 'PRIVATE_KEY_B64:' | tail -1 | base64 -d > ~/.ssh/id_rsa"
echo "  bw get item 'SSH GitHub' | jq -r '.notes' | grep -A1 'PUBLIC_KEY:' | tail -1 > ~/.ssh/id_rsa.pub"
echo "  chmod 600 ~/.ssh/id_rsa && chmod 644 ~/.ssh/id_rsa.pub"
