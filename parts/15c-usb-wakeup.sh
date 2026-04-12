#!/bin/bash
# parts/15c-usb-wakeup.sh — Configure USB wakeup (keep keyboard, disable others)

echo ""
echo "💤 Configuration du wakeup USB..."

KEYBOARD_VENDOR="3151"
KEYBOARD_PRODUCT="4010"

KEYBOARD_BUS=$(lsusb | grep "${KEYBOARD_VENDOR}:${KEYBOARD_PRODUCT}" |
  grep -o 'Bus [0-9]*' | awk '{printf "%d", $2}')

if [ -n "$KEYBOARD_BUS" ]; then
  KEYBOARD_PCI=$(readlink "/sys/bus/usb/devices/usb${KEYBOARD_BUS}" 2>/dev/null |
    grep -o '[^/]*$')
  KEYBOARD_XHC=$(grep "$KEYBOARD_PCI" /proc/acpi/wakeup | awk '{print $1}')
  echo "  ⌨️  Clavier détecté sur $KEYBOARD_XHC ($KEYBOARD_PCI)"
else
  echo "  ⚠️  Clavier non détecté — XH00 conservé par défaut"
  KEYBOARD_XHC="XH00"
fi

for dev in XHC0 XHC1 XHC3 XHC4 XH00; do
  if [ "$dev" != "$KEYBOARD_XHC" ]; then
    sudo sh -c "echo \"$dev\" > /proc/acpi/wakeup" 2>/dev/null || true
  fi
done

BT_PATH=$(find /sys/bus/usb/devices/ -name "product" 2>/dev/null |
  while read -r f; do
    grep -qi "bluetooth" "$f" && dirname "$f"
  done | head -1)

if [ -n "$BT_PATH" ]; then
  echo disabled | sudo tee "$BT_PATH/power/wakeup" >/dev/null 2>&1 || true
  echo "  ✅ Wakeup Bluetooth désactivé ($BT_PATH)"
fi

sudo tee /etc/systemd/system/disable-usb-wakeup.service >/dev/null <<'EOF'
[Unit]
Description=Disable USB wakeup (keep keyboard controller)
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c '
  KEYBOARD_BUS=$(lsusb | grep "3151:4010" | grep -o "Bus [0-9]*" | awk "{printf \"%d\", \$2}")
  KEYBOARD_PCI=$(readlink "/sys/bus/usb/devices/usb${KEYBOARD_BUS}" 2>/dev/null | grep -o "[^/]*$")
  KEYBOARD_XHC=$(grep "$KEYBOARD_PCI" /proc/acpi/wakeup | awk "{print \$1}")
  [ -z "$KEYBOARD_XHC" ] && KEYBOARD_XHC="XH00"
  for dev in XHC0 XHC1 XHC3 XHC4 XH00; do
    [ "$dev" != "$KEYBOARD_XHC" ] && echo "$dev" > /proc/acpi/wakeup
  done
  BT_PATH=$(find /sys/bus/usb/devices/ -name "product" 2>/dev/null | while read -r f; do grep -qi "bluetooth" "$f" && dirname "$f"; done | head -1)
  [ -n "$BT_PATH" ] && echo disabled > "$BT_PATH/power/wakeup" || true
'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable --now disable-usb-wakeup.service
echo "  ✅ Wakeup USB configuré (clavier $KEYBOARD_XHC conservé)"