# KDE Plasma Wayland - Virtual Keyboard & System Setup

Guide for setting up virtual keyboards on KDE Plasma 6 Wayland with **plasmalogin**
(plasma-login-manager, the KDE fork of SDDM).

Tested on: CachyOS, KWin 6.6.4, plasma-keyboard 6.6.80.

---

## Architecture overview

```
plasmalogin (display manager)
  |
  +-- greeter session (user: plasmalogin, uid 959)
  |     kwin_wayland --inputmethod plasma-keyboard --locale1 ...
  |     plasma-login-greeter (QML greeter)
  |     -> plasma-keyboard auto-shows on text focus (KWIN_IM_SHOW_ALWAYS=1)
  |
  +-- desktop session (user: wills)
        kwin_wayland_wrapper --inputmethod plasma-keyboard --xwayland
          -> spawns kwin_wayland --inputmethod plasma-keyboard --wayland-fd ... --xwayland
        plasmashell, apps, clawier (layer-shell), etc.
        -> plasma-keyboard is available but does NOT auto-show
        -> lock screen: plasma-keyboard shows via toggle button (bottom-right)
        -> regular apps: clawier handles virtual keyboard
```

### Key points

- **KWin requires `--inputmethod <name>`** to enable virtual keyboard support.
  Without it, `InputMethod` is never created, `VirtualKeyboardDBus` is not
  instantiated, and no virtual keyboard can appear. This affects both the lock
  screen toggle button AND the greeter.

- `kwin_wayland_wrapper` is a binary that forwards ALL its CLI arguments to
  `kwin_wayland` (via `qApp->arguments().mid(1)`). Adding `--inputmethod` to the
  wrapper's ExecStart works.

- The `InputMethod` setting in `~/.config/kwinrc [Wayland]` is **NOT read** by
  KWin when launched via `kwin_wayland_wrapper` -- only the `--inputmethod` CLI
  argument works.

- **`KWIN_IM_SHOW_ALWAYS=1`** forces KWin to show the virtual keyboard on text
  focus even without touch events. This should ONLY be set for the greeter (via
  service Environment=), NOT system-wide. Otherwise plasma-keyboard pops up on
  every text field in the desktop session.

- The **lock screen** (kscreenlocker) is NOT the greeter. It runs inside the
  desktop session's KWin. So the desktop KWin MUST have `--inputmethod` for the
  lock screen keyboard button to work.

- **Boot vs sleep**: after a reboot, the **greeter** appears (separate KWin with
  its own `--inputmethod` + `KWIN_IM_SHOW_ALWAYS=1`). After suspend/resume, the
  **lock screen** appears (runs inside the desktop KWin, NOT the greeter). These
  are completely different code paths with different processes.

### Two virtual keyboard approaches

| Protocol | Used by | Where | How it works |
|---|---|---|---|
| `zwp_input_method_v1` / `zwp_input_panel_v1` | plasma-keyboard | Greeter + lock screen | Compositor-managed via `--inputmethod`. KWin creates the IM surface. |
| `zwlr_layer_shell_v1` + EIS | clawier | Desktop session | Independent overlay window + emulated input. Does NOT need `--inputmethod`. |

---

## Step-by-step setup

### Prerequisites

```bash
# Install plasma-keyboard (from AUR or build from source)
# Ensure maliit-keyboard is NOT installed (conflicts)
pacman -R maliit-keyboard maliit-framework 2>/dev/null
```

### 1. Desktop session: add --inputmethod to KWin

This is needed for the **lock screen** virtual keyboard toggle to work.

```bash
mkdir -p ~/.config/systemd/user/plasma-kwin_wayland.service.d

cat > ~/.config/systemd/user/plasma-kwin_wayland.service.d/override.conf <<'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/kwin_wayland_wrapper --inputmethod plasma-keyboard --xwayland
EOF

systemctl --user daemon-reload
```

**Why the empty `ExecStart=`?** It clears the original ExecStart from the base
unit file before setting the new one. Without it, systemd would append (not
replace).

**Why won't the keyboard auto-show in apps?** Because `KWIN_IM_SHOW_ALWAYS` is
NOT set in the desktop environment. The keyboard only appears when explicitly
toggled (e.g., lock screen button, DBus call). clawier handles the desktop
virtual keyboard via layer-shell.

Verify:
```bash
systemctl --user cat plasma-kwin_wayland.service
# Should show the override with --inputmethod plasma-keyboard
```

### 2. Greeter session: fix --inputmethod + dark theme + auto-show

The base unit at `/usr/lib/systemd/user/plasma-login-kwin_wayland.service` ships
with `--inputmethod maliit-keyboard`. Override it to use plasma-keyboard and
enable auto-show:

```bash
sudo mkdir -p /etc/systemd/user/plasma-login-kwin_wayland.service.d

sudo tee /etc/systemd/user/plasma-login-kwin_wayland.service.d/override.conf <<'EOF'
[Service]
Environment=KWIN_IM_SHOW_ALWAYS=1
ExecStart=
ExecStart=/usr/bin/kwin_wayland --no-lockscreen --no-global-shortcuts --no-kactivities --inputmethod plasma-keyboard --locale1
EOF

sudo systemctl daemon-reload
```

Note: `/etc/systemd/user/` overrides apply to ALL users' user services, including
the `plasmalogin` system user (uid 959, home `/var/lib/plasmalogin/`) that runs
the greeter.

**`KWIN_IM_SHOW_ALWAYS=1`** is set HERE (greeter only), NOT in `/etc/environment`.
This way the keyboard auto-shows on the login screen but not in desktop apps.

### 3. Greeter dark theme

plasma-keyboard derives all its colors from `Kirigami.Theme`, which reads from
`kdeglobals`. The plasmalogin user has no `kdeglobals` by default, so it falls
back to the light Breeze theme (white keyboard).

Copy the BreezeDark color scheme as the plasmalogin user's `kdeglobals`:

```bash
sudo mkdir -p /var/lib/plasmalogin/.config
sudo cp /usr/share/color-schemes/BreezeDark.colors /var/lib/plasmalogin/.config/kdeglobals
sudo chown plasmalogin:plasmalogin /var/lib/plasmalogin/.config /var/lib/plasmalogin/.config/kdeglobals
```

This works because `BreezeDark.colors` uses the exact same INI format as
`kdeglobals` (`[Colors:Window]`, `[Colors:Button]`, etc.). Kirigami reads these
sections and applies the dark palette to all Qt/Kirigami UI, including the
keyboard. No code changes needed.

### 4. /etc/environment

`/etc/environment` should contain:

```
LANG=fr_FR.UTF-8
```

**Do NOT put `KWIN_IM_SHOW_ALWAYS=1` here** -- it's now in the greeter service
override only (step 2).

### 5. Locale fix (optional)

If `LC_PAPER` or `LC_NAME` point to `en_GB.UTF-8` and you see locale warnings:

```bash
sudo sed -i 's/#en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/' /etc/locale.gen
sudo locale-gen
```

### 6. Reboot and test

```bash
systemctl reboot
```

After reboot:
- **Greeter**: plasma-keyboard auto-shows on password field focus (dark theme)
- **Lock screen**: click the keyboard icon (bottom-right) to toggle plasma-keyboard
- **Desktop apps**: plasma-keyboard does NOT auto-show; clawier handles input

Verify the desktop session KWin has the flag:
```bash
cat /proc/$(pgrep -x kwin_wayland)/cmdline | tr '\0' ' '
# Should contain: --inputmethod plasma-keyboard
```

Verify VirtualKeyboard is available:
```bash
qdbus6 org.kde.KWin /VirtualKeyboard org.freedesktop.DBus.Properties.GetAll org.kde.kwin.VirtualKeyboard
# available should be true
```

---

## Troubleshooting

### "Could not find slot KWin::VirtualKeyboardDBus::enabled/visible/active"

KWin was started WITHOUT `--inputmethod`. The `InputMethod` object was never
created so `VirtualKeyboardDBus` slots don't exist. Fix the systemd override.

### "Failed to initialize input panel shell integration"

plasma-keyboard can't bind to `zwp_input_panel_v1`. This means KWin's input
method support is not active. Check that `--inputmethod plasma-keyboard` is in
the KWin command line.

### Lock screen keyboard button does nothing

The desktop KWin must have `--inputmethod plasma-keyboard`. Without it,
`VirtualKeyboard.available` is false and the toggle has no effect. Check:
```bash
qdbus6 org.kde.KWin /VirtualKeyboard org.freedesktop.DBus.Properties.Get \
  org.kde.kwin.VirtualKeyboard available
# Must be true
```

### Lock screen keyboard doesn't work after suspend/resume

**Root cause**: After suspend/resume, KWin rebuilds DRM outputs (~8-13 seconds
after resume on this machine). All `wl_output` objects are destroyed and new
ones created. plasma-keyboard's `zwp_input_panel_surface_v1` was bound to the
old output via `set_toplevel(output, position)`, and becomes stale. KWin's
server-side `InputPanelSurfaceV1Interface` also holds a reference to the dead
output.

Log signature after resume:
```
kwin_wayland: Input Method crashed "plasma-keyboard" QList() 9 QProcess::CrashExit
plasma-keyboard: There are no outputs - creating placeholder screen
kscreenlocker_greet: There are no outputs - creating placeholder screen
```

**Workaround**: From the lock screen, click "Switch User". This launches the
plasmalogin greeter — a completely separate KWin process that never went through
suspend/resume. All Wayland state is fresh so the keyboard works normally.

### Keyboard auto-shows on every text field in desktop apps

`KWIN_IM_SHOW_ALWAYS=1` is set globally. Remove it from `/etc/environment` and
set it only in the greeter service override (see step 2).

### Greeter keyboard is white / light theme

The plasmalogin user's `kdeglobals` is missing or uses the default light theme:
```bash
sudo cp /usr/share/color-schemes/BreezeDark.colors /var/lib/plasmalogin/.config/kdeglobals
sudo chown plasmalogin:plasmalogin /var/lib/plasmalogin/.config/kdeglobals
```

### Keyboard appears but is wrong size / on wrong monitor

`Screen.height` / `Screen.width` in plasma-keyboard's QML refers to the screen
the window is on. The compositor positions the input panel via
`zwp_input_panel_v1` on the active output. Do NOT change these to
`Screen.desktopAvailableHeight` -- the input panel window must be full-screen
size (the `interactiveRegion` / `setMask()` handles limiting the clickable area
to the keyboard panel only).

### Locale warnings (LC_PAPER, LC_NAME)

If you see locale errors for `en_GB.UTF-8`:
```bash
sudo sed -i 's/#en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/' /etc/locale.gen
sudo locale-gen
```

---

## USB wakeup configuration

Separate from the keyboard setup, but part of the bootstrap.

**Goal**: allow waking from sleep with the USB keyboard (EPOMAKER TH80 Pro,
`3151:4010`) but NOT with the Bluetooth mouse or other USB devices.

### How it works

`/proc/acpi/wakeup` controls which ACPI devices can wake the system. Writing a
device name TOGGLES its state (enabled/disabled). USB host controllers are named
`XHC*` or `XH**`.

The script at `/usr/local/bin/disable-usb-wakeup.sh`:
1. Finds which USB controller hosts the keyboard (via bus → PCI → ACPI mapping)
2. Disables wakeup for all other USB controllers (only if currently enabled)
3. Ensures the keyboard's controller stays enabled
4. Disables Bluetooth device-level wakeup

### Bugs fixed in the old inline service approach

The previous version inlined the script in `ExecStart=/bin/bash -c '...'`.
This had three bugs:

1. **systemd expands `$VAR` / `${VAR}` as its own env vars** before bash runs.
   All shell variables (`$KB_BUS`, `${KB_BUS}`, etc.) were silently replaced
   with empty strings, making the entire script non-functional.

2. **`grep -o "[0-9]*"` gives zero-padded bus numbers** (e.g., `001`) but sysfs
   uses `usb1` (unpadded). Fix: `awk '{printf "%d", $2}'` to strip zeros.

3. **Toggle logic assumed initial state**: the "re-enable keyboard" block toggled
   an already-enabled device, disabling it instead. Fix: check `*enabled` /
   `*disabled` state before toggling.

### Current fix

External script (`/usr/local/bin/disable-usb-wakeup.sh`) called by a simple
systemd service. See `~/.dotfiles/parts/15c-usb-wakeup.sh` for the installer.

---

## File reference

### Systemd services

| File | Purpose |
|---|---|
| `/usr/lib/systemd/user/plasma-kwin_wayland.service` | Desktop session KWin (base, no --inputmethod) |
| `~/.config/systemd/user/plasma-kwin_wayland.service.d/override.conf` | Desktop override (adds `--inputmethod plasma-keyboard`) |
| `/usr/lib/systemd/user/plasma-login-kwin_wayland.service` | Greeter KWin (base, ships with maliit-keyboard) |
| `/etc/systemd/user/plasma-login-kwin_wayland.service.d/override.conf` | Greeter override (`--inputmethod plasma-keyboard` + `KWIN_IM_SHOW_ALWAYS=1`) |
| `/usr/lib/systemd/system/plasmalogin.service` | Display manager service |
| `/etc/systemd/system/disable-usb-wakeup.service` | USB wakeup config at boot |

### Configuration

| File | Purpose |
|---|---|
| `/etc/environment` | `LANG=fr_FR.UTF-8` only (NO KWIN_IM_SHOW_ALWAYS here) |
| `/etc/plasmalogin.conf` | plasmalogin config (autologin, session type) |
| `/var/lib/plasmalogin/.config/kdeglobals` | Greeter color scheme (BreezeDark for dark keyboard) |
| `~/.config/kwinrc` | KWin config (NOTE: `[Wayland] InputMethod=` is NOT read by the wrapper) |

### Scripts & binaries

| Path | Purpose |
|---|---|
| `/usr/bin/plasma-keyboard` | Virtual keyboard (zwp_input_method_v1) |
| `/usr/bin/kwin_wayland` | KDE Wayland compositor |
| `/usr/bin/kwin_wayland_wrapper` | Wrapper that sets up sockets then forwards all args to kwin_wayland |
| `/usr/lib/plasma-login-greeter` | plasmalogin greeter binary |
| `/usr/local/bin/disable-usb-wakeup.sh` | USB wakeup disable script (called by systemd) |

### Color scheme

| File | Purpose |
|---|---|
| `/usr/share/color-schemes/BreezeDark.colors` | Source dark color scheme |
| `/var/lib/plasmalogin/.config/kdeglobals` | Copy of above, makes greeter UI dark |

plasma-keyboard's `BreezeConstants.qml` reads all colors from `Kirigami.Theme`
which reads from `kdeglobals`. The key properties are `Kirigami.Theme.backgroundColor`
(-> `primaryColor` -> `keyboardBackgroundColor`) and `Kirigami.Theme.textColor`
(-> `textOnPrimaryColor` -> `keyTextColor`). No code changes needed for theming.

---

## For clawier (desktop virtual keyboard)

clawier uses `zwlr_layer_shell_v1` + EIS, NOT `zwp_input_method_v1`. It works
independently of `--inputmethod` and does not require any KWin configuration.

The split is:
- **Greeter (login screen)**: plasma-keyboard via `--inputmethod` + auto-show
- **Lock screen**: plasma-keyboard via toggle button (same KWin as desktop)
- **Desktop session**: clawier via layer-shell + EIS (no `--inputmethod` needed)

The greeter MUST use plasma-keyboard (or another zwp_input_method_v1 keyboard)
since clawier requires EIS portal access which is not available in the greeter
session.
