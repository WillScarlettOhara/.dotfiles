#!/bin/bash

CURRENT=$(gsettings get org.gnome.desktop.a11y.magnifier mag-factor)
CURRENT=${CURRENT//,/\.}

NEW_VAL=$(awk "BEGIN {print $CURRENT - 0.5}")
IS_MIN=$(awk "BEGIN {if ($NEW_VAL <= 1.0) print 1; else print 0}")

if [ "$IS_MIN" -eq 1 ]; then
  # On remet à la normale et on désactive la loupe
  gsettings set org.gnome.desktop.a11y.magnifier mag-factor 1.0
  gsettings set org.gnome.desktop.a11y.applications screen-magnifier-enabled false
else
  gsettings set org.gnome.desktop.a11y.magnifier mag-factor "$NEW_VAL"
fi
