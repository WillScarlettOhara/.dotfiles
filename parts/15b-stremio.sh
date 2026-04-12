#!/bin/bash
# parts/15b-stremio.sh — Stremio AUR install with CEF patch

echo ""
echo "🎬 Installation de Stremio..."

if command -v stremio &>/dev/null; then
  echo "  ✅ Stremio déjà installé."
  # Verify it actually launches (CEF lib check)
  if ! LD_LIBRARY_PATH=/usr/lib/stremio/cef stremio --version &>/dev/null; then
    echo "  ⚠️  Stremio ne se lance pas (CEF) — réinstallation..."
  else
    exit 0
  fi
fi

# Write the patch script only when needed
cat >/tmp/stremio_patch.py <<'PYEOF'
import re, pathlib, sys

NEW_PACKAGE = r"""package() {
  cd "stremio-linux-shell"
  install -Dm755 "target/release/stremio-linux-shell" "$pkgdir/usr/bin/stremio"
  install -Dm644 "data/com.stremio.Stremio.desktop" \
    "$pkgdir/usr/share/applications/com.stremio.Stremio.desktop"
  sed -i '/^[[:space:]]*DBusActivatable[[:space:]]*=[[:space:]]*true[[:space:]]*$/d' \
    "$pkgdir/usr/share/applications/com.stremio.Stremio.desktop"
  install -Dm644 "data/icons/com.stremio.Stremio.svg" \
    "$pkgdir/usr/share/icons/hicolor/scalable/apps/com.stremio.Stremio.svg"
  install -Dm644 "data/com.stremio.Stremio.metainfo.xml" \
    "$pkgdir/usr/share/metainfo/com.stremio.Stremio.metainfo.xml"
  install -Dm644 /usr/share/licenses/spdx/GPL-3.0-only.txt \
    "$pkgdir/usr/share/licenses/$pkgname/LICENSE.txt"
  install -dm755 "$pkgdir/usr/lib/stremio/cef"
  cp -r vendor/cef/* "$pkgdir/usr/lib/stremio/cef/"
  install -dm755 "$pkgdir/usr/lib/stremio"
  mv "$pkgdir/usr/bin/stremio" "$pkgdir/usr/lib/stremio/stremio-bin"
  install -Dm644 "data/server.js" "$pkgdir/usr/lib/stremio/server.js"
  cat > "$pkgdir/usr/bin/stremio" <<'EOF'
#!/bin/bash
export LD_LIBRARY_PATH="/usr/lib/stremio/cef:$LD_LIBRARY_PATH"
export CEF_FLAGS="--enable-features=ClipboardContentSetting --enable-clipboard --disable-gpu-sandbox"
cd /usr/lib/stremio
exec /usr/lib/stremio/stremio-bin $CEF_FLAGS "$@"
EOF
  chmod +x "$pkgdir/usr/bin/stremio"
}"""

pkgbuild_path = pathlib.Path("PKGBUILD")
pkgbuild = pkgbuild_path.read_text()
patched = re.sub(r"(?ms)^package\(\)\s*\{.*?^\}", NEW_PACKAGE, pkgbuild)

if patched == pkgbuild:
    print("  ❌ Section package() non trouvée dans le PKGBUILD.")
    sys.exit(1)

pkgbuild_path.write_text(patched)
print("  ✅ PKGBUILD patché avec succès.")
PYEOF

install_stremio() {
  local dir="/tmp/stremio"

  git clone https://aur.archlinux.org/stremio-linux-shell-git.git "$dir" 2>/dev/null ||
    git -C "$dir" pull --ff-only

  (
    cd "$dir"

    if grep -q "LD_LIBRARY_PATH" PKGBUILD; then
      echo "  ℹ️  PKGBUILD déjà patché, skip."
    else
      python3 /tmp/stremio_patch.py || {
        echo "  ❌ Patch échoué."
        exit 1
      }
    fi

    makepkg -si --noconfirm
  )
}

install_stremio && echo "  ✅ Stremio installé." || echo "  ⚠️  Échec installation Stremio."
rm -f /tmp/stremio_patch.py