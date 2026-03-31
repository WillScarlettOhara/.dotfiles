#!/bin/bash
# post_relog.sh - À lancer manuellement APRES le premier "log out / log in"

echo "🚀 Activation des extensions GNOME..."

# L'extension ArcMenu utilise l'UUID 'arcmenu@arcmenu.com'
gnome-extensions enable dash-to-panel@jderose9.github.com
gnome-extensions enable arcmenu@arcmenu.com
gnome-extensions enable Vitals@CoreCoding.com
gnome-extensions enable gjsosk@vishram1123.com

echo "✅ Toutes les extensions ont été activées !"
