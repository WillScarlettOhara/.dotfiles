#!/bin/bash
# parts/11-bitwarden-secrets.sh — Fetch secrets from Bitwarden (rclone, restic, DNS)

echo ""
echo "🔐 Récupération des secrets Bitwarden..."

export RESTIC_PASSWORD
RESTIC_PASSWORD=$(bw list items --search "Restic Password" --session "$BW_SESSION" 2>/dev/null |
  jq -r '.[] | select(.name == "Restic Password") | (.notes // .login.password // empty)')

if [ -z "$RESTIC_PASSWORD" ]; then
  echo "❌ Mot de passe Restic introuvable. Abandon."
  exit 1
fi

mkdir -p ~/.config/rclone
bw list items --search "Config Rclone" --session "$BW_SESSION" 2>/dev/null |
  jq -r '.[] | select(.name == "Config Rclone") | .notes // empty' >~/.config/rclone/rclone.conf

NETWORK_CONFIG=$(bw list items --search "Network Config" --session "$BW_SESSION" 2>/dev/null |
  jq -r '.[] | select(.name == "Network Config") | .notes // empty')
DNS_PRIMARY=$(echo "$NETWORK_CONFIG" | grep "^DNS_PRIMARY=" | cut -d= -f2)
DNS_FALLBACK=$(echo "$NETWORK_CONFIG" | grep "^DNS_FALLBACK=" | cut -d= -f2)

bw lock &>/dev/null

ACTIVE_CON=$(nmcli -t -f NAME connection show --active | head -n1)
nmcli connection modify "$ACTIVE_CON" \
  ipv4.dns "$DNS_PRIMARY $DNS_FALLBACK" \
  ipv4.ignore-auto-dns yes
nmcli connection up "$ACTIVE_CON"

sudo mkdir -p /etc/systemd/resolved.conf.d
sudo tee /etc/systemd/resolved.conf.d/dns.conf >/dev/null <<EOF
[Resolve]
DNS=$DNS_PRIMARY
FallbackDNS=$DNS_FALLBACK
EOF
sudo systemctl restart systemd-resolved
echo "  ✅ DNS → $DNS_PRIMARY (principal) $DNS_FALLBACK (fallback)"