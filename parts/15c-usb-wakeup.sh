#!/bin/bash
# parts/15c-usb-wakeup.sh — Configure USB wakeup (keep keyboard, disable others)

echo ""
echo "💤 Configuration du wakeup USB..."

KEYBOARD_VENDOR="3151"
KEYBOARD_PRODUCT="4010"

KEYBOARD_BUS=$(lsusb | grep "${KEYBOARD_VENDOR}:${KEYBOARD_PRODUCT}" |
  grep -o 'Bus [0-9]*' | awk '{printf "%d", $2}' || true)

KEYBOARD_XHC=""
if [ -n "$KEYBOARD_BUS" ]; then
  # readlink gives .../0000:0e:00.0/usb1 — we need the PCI address (parent of usbN)
  KEYBOARD_PCI=$(basename "$(dirname "$(readlink "/sys/bus/usb/devices/usb${KEYBOARD_BUS}" 2>/dev/null)")" 2>/dev/null || true)
  if [ -n "$KEYBOARD_PCI" ]; then
    KEYBOARD_XHC=$(grep "$KEYBOARD_PCI" /proc/acpi/wakeup 2>/dev/null | awk '{print $1}' || true)
  fi
fi

if [ -n "$KEYBOARD_XHC" ]; then
  echo "  ⌨️  Clavier détecté sur $KEYBOARD_XHC ($KEYBOARD_PCI)"
else
  echo "  ⚠️  Clavier non détecté — aucun contrôleur USB ne sera préservé"
fi

# Dynamically discover all USB host controller wakeup devices (XHC*, XH**)
USB_WAKEUP_DEVS=$(awk '/^XH/ {print $1}' /proc/acpi/wakeup 2>/dev/null || true)

for dev in $USB_WAKEUP_DEVS; do
  if [ "$dev" != "$KEYBOARD_XHC" ]; then
    sudo sh -c "echo \"$dev\" > /proc/acpi/wakeup" 2>/dev/null || true
  fi
done

BT_PATH=$(find /sys/bus/usb/devices/ -name "product" 2>/dev/null |
  while read -r f; do
    grep -qi "bluetooth" "$f" && dirname "$f"
  done | head -1 || true)

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
ExecStart=/bin/bash -c '\
  set +e; \
  KB_BUS=$(lsusb | grep "3151:4010" | grep -o "Bus [0-9]*" | grep -o "[0-9]*" | head -1); \
  KB_XHC=""; \
  if [ -n "$KB_BUS" ]; then \
    KB_PCI=$(basename "$(dirname "$(readlink /sys/bus/usb/devices/usb${KB_BUS})")"); \
    [ -n "$KB_PCI" ] && KB_XHC=$(grep "$KB_PCI" /proc/acpi/wakeup | awk "{print \$$1}"); \
  fi; \
  echo "Keyboard on XHC: ${KB_XHC:-NOT_FOUND}" >&2; \
  for dev in $(awk "/^XH/ {print \$$1}" /proc/acpi/wakeup); do \
    [ "$dev" != "$KB_XHC" ] && echo "$dev" > /proc/acpi/wakeup; \
  done; \
  if [ -n "$KB_XHC" ]; then \
    echo "$KB_XHC" > /proc/acpi/wakeup; \
  fi; \
  BT=$(find /sys/bus/usb/devices/ -name product 2>/dev/null | while read f; do grep -qi bluetooth "$f" && dirname "$f"; done | head -1); \
  [ -n "$BT" ] && echo disabled > "$BT/power/wakeup"; \
  true'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now disable-usb-wakeup.service
echo "  ✅ Wakeup USB configuré${KEYBOARD_XHC:+ (clavier $KEYBOARD_XHC conservé)}"
