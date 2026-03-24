#!/bin/bash
CURRENT=$(gsettings get org.gnome.desktop.a11y.magnifier mag-factor)
gsettings set org.gnome.desktop.a11y.magnifier mag-factor $(echo "$CURRENT + 0.5" | bc)
