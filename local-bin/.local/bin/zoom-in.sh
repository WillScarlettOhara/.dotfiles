#!/bin/bash

# Activer la loupe de GNOME (obligatoire pour voir le zoom)
gsettings set org.gnome.desktop.a11y.applications screen-magnifier-enabled true

# Obtenir le facteur de zoom actuel et contourner le bug des virgules (Fr)
CURRENT=$(gsettings get org.gnome.desktop.a11y.magnifier mag-factor)
CURRENT=${CURRENT//,/\.}

# Calculer la nouvelle valeur avec awk
NEW_VAL=$(awk "BEGIN {print $CURRENT + 0.5}")

# Appliquer le zoom
gsettings set org.gnome.desktop.a11y.magnifier mag-factor "$NEW_VAL"
