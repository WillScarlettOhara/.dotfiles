#!/bin/bash
CURRENT=$(gsettings get org.gnome.desktop.a11y.magnifier mag-factor)
NEW=$(echo "$CURRENT - 0.5" | bc)
if (( $(echo "$NEW < 1.0" | bc -l) )); then NEW=1.0; fi
gsettings set org.gnome.desktop.a11y.magnifier mag-factor $NEW
