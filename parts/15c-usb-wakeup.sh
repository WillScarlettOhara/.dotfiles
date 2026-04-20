#!/bin/bash
# parts/15c-usb-wakeup.sh — Configure USB wakeup (keep keyboard, disable others)
#
# Installs an external script + systemd service. The script is NOT inlined in
# the service ExecStart because systemd expands $VAR/${VAR} as its own env vars
# before bash sees them, which silently breaks all shell logic.

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

# --- Install the boot-time script ---

sudo tee /usr/local/bin/disable-usb-wakeup.sh >/dev/null <<'SCRIPT'
#!/bin/bash
# Disable USB wakeup for all controllers except the one hosting the keyboard.
# Writing to /proc/acpi/wakeup TOGGLES state, so we check before toggling.
set -euo pipefail

KEYBOARD_VENDOR="3151"
KEYBOARD_PRODUCT="4010"

# Find keyboard USB bus number (strip leading zeros — sysfs uses usb1 not usb001)
KB_BUS=$(lsusb | grep "${KEYBOARD_VENDOR}:${KEYBOARD_PRODUCT}" |
  grep -o 'Bus [0-9]*' | awk '{printf "%d", $2}' || true)

KB_XHC=""
if [ -n "$KB_BUS" ]; then
  KB_PCI=$(basename "$(dirname "$(readlink "/sys/bus/usb/devices/usb${KB_BUS}" 2>/dev/null)")" 2>/dev/null || true)
  if [ -n "$KB_PCI" ]; then
    KB_XHC=$(grep "$KB_PCI" /proc/acpi/wakeup 2>/dev/null | awk '{print $1}' || true)
  fi
fi

echo "Keyboard controller: ${KB_XHC:-NOT_FOUND} (bus ${KB_BUS:-?}, PCI ${KB_PCI:-?})" >&2

# Disable wakeup for all USB host controllers (XH*) except the keyboard's.
# Only toggle devices that are currently *enabled* to avoid double-toggle.
while read -r line; do
  dev=$(echo "$line" | awk '{print $1}')
  [[ "$dev" =~ ^XH ]] || continue
  [ "$dev" = "$KB_XHC" ] && continue
  echo "$line" | grep -q '\*enabled' || continue
  echo "Disabling wakeup: $dev" >&2
  echo "$dev" > /proc/acpi/wakeup
done < /proc/acpi/wakeup

# Ensure keyboard controller is enabled (toggle only if currently disabled)
if [ -n "$KB_XHC" ]; then
  if grep "^${KB_XHC}[[:space:]]" /proc/acpi/wakeup | grep -q '\*disabled'; then
    echo "Enabling wakeup: $KB_XHC" >&2
    echo "$KB_XHC" > /proc/acpi/wakeup
  else
    echo "Wakeup already enabled: $KB_XHC" >&2
  fi
fi

# Disable Bluetooth device-level wakeup
BT_PATH=$(find /sys/bus/usb/devices/ -name "product" 2>/dev/null |
  while read -r f; do
    grep -qi "bluetooth" "$f" && dirname "$f"
  done | head -1 || true)

if [ -n "$BT_PATH" ] && [ -f "$BT_PATH/power/wakeup" ]; then
  echo "disabled" > "$BT_PATH/power/wakeup"
  echo "Bluetooth wakeup disabled: $BT_PATH" >&2
fi
SCRIPT

sudo chmod 755 /usr/local/bin/disable-usb-wakeup.sh

# --- Install the systemd service ---

sudo tee /etc/systemd/system/disable-usb-wakeup.service >/dev/null <<'EOF'
[Unit]
Description=Disable USB wakeup (keep keyboard controller)
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/disable-usb-wakeup.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now disable-usb-wakeup.service
echo "  ✅ Wakeup USB configuré${KEYBOARD_XHC:+ (clavier $KEYBOARD_XHC conservé)}"
