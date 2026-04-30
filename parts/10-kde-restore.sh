#!/bin/bash
# parts/10-kde-restore.sh — Restore KDE Plasma settings

if [ "$IS_KDE" != true ]; then
  return 0
fi

echo ""
echo "⚙️  Restauration des configs KDE Plasma..."

# Les fichiers sont déjà symlinkés via stow kde dans ~/.config/
# On force le rechargement de certains composants pour appliquer immédiatement.

if command -v kwriteconfig5 &>/dev/null; then
  # Forcer le rechargement du thème d'icônes
  kwriteconfig5 --file kdeglobals --group Icons --key Theme "Gruvbox" 2>/dev/null || true
  # Forcer le rechargement du style widget
  kwriteconfig5 --file kdeglobals --group KDE --key widgetStyle "Breeze" 2>/dev/null || true
  # Forcer le Look & Feel
  kwriteconfig5 --file kdeglobals --group KDE --key LookAndFeelPackage "org.kde.breezedark.desktop" 2>/dev/null || true
  echo "  ✅ Préférences KDE écrites."
fi

# Recharger KWin si possible pour appliquer les bordures et effets
if command -v qdbus &>/dev/null; then
  qdbus org.kde.KWin /KWin reconfigure 2>/dev/null || true
fi

echo "  ✅ Configs KDE restaurées (redémarrage de la session recommandé pour tout appliquer)."
