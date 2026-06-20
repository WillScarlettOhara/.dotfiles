#!/bin/bash
# parts/17-rustdesk.sh — RustDesk Server Docker

echo ""
echo "🖥️  Configuration de RustDesk Server..."

RUSTDESK_DATA="$HOME/.local/share/rustdesk-server"
mkdir -p "$RUSTDESK_DATA"

# --- Ensure Docker is running ---
if ! systemctl is-active --quiet docker.service; then
  echo "  🐳 Démarrage de Docker..."
  sudo systemctl enable --now docker.service
fi

# --- Ensure user is in docker group ---
if ! groups "$USER" | grep -qw docker; then
  echo "  👤 Ajout de $USER au groupe docker..."
  sudo usermod -aG docker "$USER"
fi

# Helper to run docker compose with correct group context
_docker_compose() {
  if groups "$USER" | grep -qw docker; then
    docker compose "$@"
  else
    sg docker -c "docker compose $*"
  fi
}

# --- Install systemd service ---
echo "  📄 Installation du service systemd..."
sudo tee /etc/systemd/system/rustdesk-server.service >/dev/null <<EOF
[Unit]
Description=RustDesk Server (hbbs + hbbr)
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$HOME/.dotfiles/docker/rustdesk
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
ExecReload=/usr/bin/docker compose up -d

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now rustdesk-server.service

# --- Pull and start containers ---
echo "  📥 Pull des images RustDesk Server..."
_docker_compose -f "$HOME/.dotfiles/docker/rustdesk/docker-compose.yml" pull

echo "  🚀 Démarrage des conteneurs..."
_docker_compose -f "$HOME/.dotfiles/docker/rustdesk/docker-compose.yml" up -d

# Wait for key generation
echo "  ⏳ Attente de la génération des clés..."
for _ in {1..30}; do
  if [ -f "$RUSTDESK_DATA/id_ed25519.pub" ]; then
    break
  fi
  sleep 2
done

# --- Firewall ---
echo "  🔥 Configuration du pare-feu..."
if command -v firewall-cmd &>/dev/null; then
  sudo firewall-cmd --permanent --add-port=21115/tcp
  sudo firewall-cmd --permanent --add-port=21116/tcp
  sudo firewall-cmd --permanent --add-port=21116/udp
  sudo firewall-cmd --permanent --add-port=21117/tcp
  sudo firewall-cmd --reload
  echo "    ✅ Ports ouverts via firewall-cmd."
elif command -v ufw &>/dev/null; then
  sudo ufw allow 21115/tcp
  sudo ufw allow 21116/tcp
  sudo ufw allow 21116/udp
  sudo ufw allow 21117/tcp
  echo "    ✅ Ports ouverts via ufw."
else
  echo "    ⚠️  Aucun pare-feu détecté (firewall-cmd/ufw)."
fi

echo ""
echo "✅ RustDesk Server configuré."
echo ""
echo "════════════════════════════════════════════════════════════"
echo "📋 INFORMATIONS DE CONNEXION"
echo "════════════════════════════════════════════════════════════"
echo ""
if [ -f "$RUSTDESK_DATA/id_ed25519.pub" ]; then
  echo "🔑 Clé publique du serveur :"
  cat "$RUSTDESK_DATA/id_ed25519.pub"
else
  echo "⚠️  Clé non encore générée. Vérifiez les logs :"
  echo "   docker logs rustdesk-hbbs"
fi
echo ""
echo "⚠️  NE REDIRIGEZ PAS ces ports sur Internet (Freebox) :"
echo "   21115/tcp, 21116/tcp+udp, 21117/tcp"
echo ""
echo "   Accès autorisé uniquement via :"
echo "   • Réseau local (LAN)"
echo "   • VPN WireGuard Freebox (port 5327)"
echo ""
echo "   Dans le client RustDesk, configurez :"
echo "   • ID Server   : <IP locale ou IP VPN du PC>"
echo "   • Relay Server: <IP locale ou IP VPN du PC>"
echo "   • Key         : (voir clé publique ci-dessus)"
echo "════════════════════════════════════════════════════════════"
