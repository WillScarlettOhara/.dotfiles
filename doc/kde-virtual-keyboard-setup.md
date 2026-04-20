# KDE Plasma Wayland - Virtual Keyboard Setup

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
  |     -> plasma-keyboard appears only here (greeter login screen)
  |
  +-- desktop session (user: wills)
        kwin_wayland_wrapper --xwayland   (NO --inputmethod)
        plasmashell, apps, clawier (layer-shell), etc.
        -> clawier handles virtual keyboard in desktop session
```

### Key points

- **KWin requires `--inputmethod <name>`** to enable virtual keyboard support.
  Without it, `InputMethod` is never created, `VirtualKeyboardDBus` is not
  instantiated, and no virtual keyboard can appear.

- `kwin_wayland_wrapper` is a binary that forwards ALL its CLI arguments to
  `kwin_wayland` (via `qApp->arguments().mid(1)`). Adding `--inputmethod` to the
  wrapper's ExecStart works.

- The `InputMethod` setting in `~/.config/kwinrc [Wayland]` is **NOT read** by
  KWin when launched via `kwin_wayland_wrapper` -- only the `--inputmethod` CLI
  argument works.

- `KWIN_IM_SHOW_ALWAYS=1` in `/etc/environment` forces KWin to show the virtual
  keyboard even without touch events (mouse-only setups).

### Two virtual keyboard approaches

| Protocol | Used by | Where | How it works |
|---|---|---|---|
| `zwp_input_method_v1` / `zwp_input_panel_v1` | plasma-keyboard | Greeter only | Compositor-managed via `--inputmethod`. KWin creates the IM surface. |
| `zwlr_layer_shell_v1` + EIS | clawier | Desktop session | Independent overlay window + emulated input. Does NOT need `--inputmethod`. |

---

## Step-by-step setup

### Prerequisites

```bash
# Install plasma-keyboard (from AUR or build from source)
# Ensure maliit-keyboard is NOT installed (conflicts)
pacman -R maliit-keyboard maliit-framework 2>/dev/null
```

### 1. Greeter session: add --inputmethod plasma-keyboard

The base unit at `/usr/lib/systemd/user/plasma-login-kwin_wayland.service` ships
with `--inputmethod maliit-keyboard`. Override it to use plasma-keyboard:

```bash
sudo mkdir -p /etc/systemd/user/plasma-login-kwin_wayland.service.d

sudo tee /etc/systemd/user/plasma-login-kwin_wayland.service.d/override.conf <<'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/kwin_wayland --no-lockscreen --no-global-shortcuts --no-kactivities --inputmethod plasma-keyboard --locale1
EOF

sudo systemctl daemon-reload
```

**Why the empty `ExecStart=`?** It clears the original ExecStart from the base
unit file before setting the new one. Without it, systemd would append (not
replace).

Note: `/etc/systemd/user/` overrides apply to ALL users' user services, including
the `plasmalogin` system user that runs the greeter.

### 2. Greeter dark theme

plasma-keyboard derives all its colors from `Kirigami.Theme`, which reads from
`kdeglobals`. The plasmalogin user has no `kdeglobals` by default, so it falls
back to the light Breeze theme.

To make the greeter keyboard dark, copy the BreezeDark color scheme as the
plasmalogin user's `kdeglobals`:

```bash
sudo mkdir -p /var/lib/plasmalogin/.config
sudo cp /usr/share/color-schemes/BreezeDark.colors /var/lib/plasmalogin/.config/kdeglobals
sudo chown plasmalogin:plasmalogin /var/lib/plasmalogin/.config /var/lib/plasmalogin/.config/kdeglobals
```

This works because `BreezeDark.colors` uses the exact same INI format as
`kdeglobals` (`[Colors:Window]`, `[Colors:Button]`, etc.). Kirigami reads these
sections and applies the dark palette to all Qt/Kirigami UI, including the
keyboard.

### 3. Desktop session: NO --inputmethod (intentional)

The desktop session KWin service at
`/usr/lib/systemd/user/plasma-kwin_wayland.service` launches:

```
ExecStart=/usr/bin/kwin_wayland_wrapper --xwayland
```

**Do NOT add `--inputmethod` here** unless you want plasma-keyboard to pop up on
every text field in the desktop session. The desktop uses clawier instead, which
works via `zwlr_layer_shell_v1` + EIS and does not need `--inputmethod`.

If you ever need plasma-keyboard in the desktop session too (e.g., for testing),
create a user override:

```bash
mkdir -p ~/.config/systemd/user/plasma-kwin_wayland.service.d
cat > ~/.config/systemd/user/plasma-kwin_wayland.service.d/override.conf <<'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/kwin_wayland_wrapper --inputmethod plasma-keyboard --xwayland
EOF
systemctl --user daemon-reload
```

To remove it again:
```bash
rm ~/.config/systemd/user/plasma-kwin_wayland.service.d/override.conf
rmdir ~/.config/systemd/user/plasma-kwin_wayland.service.d
systemctl --user daemon-reload
```

### 4. Environment variable

Add to `/etc/environment`:

```
KWIN_IM_SHOW_ALWAYS=1
```

This forces KWin to show the virtual keyboard on focus of text fields, even
without touch input events. Required for mouse-only or non-touchscreen setups.

### 5. Reboot and test

```bash
systemctl reboot
```

After reboot:
- The **greeter** should show plasma-keyboard (dark theme) when the password
  field is focused
- The **desktop session** should NOT show plasma-keyboard (use clawier instead)

Check greeter KWin logs for errors:
```bash
sudo journalctl --user -u plasma-login-kwin_wayland.service -b -M plasmalogin@
# or check the journal for the plasmalogin user
journalctl _UID=959 -b | grep -i 'input\|keyboard'
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

### Keyboard appears but is wrong size / on wrong monitor

`Screen.height` / `Screen.width` in plasma-keyboard's QML refers to the screen
the window is on. The compositor positions the input panel via
`zwp_input_panel_v1` on the active output. Do NOT change these to
`Screen.desktopAvailableHeight` -- the input panel window must be full-screen
size (the `interactiveRegion` / `setMask()` handles limiting the clickable area
to the keyboard panel only).

### Greeter keyboard is white / light theme

The plasmalogin user's `kdeglobals` is missing or uses the default light theme.
Copy the BreezeDark color scheme:
```bash
sudo cp /usr/share/color-schemes/BreezeDark.colors /var/lib/plasmalogin/.config/kdeglobals
sudo chown plasmalogin:plasmalogin /var/lib/plasmalogin/.config/kdeglobals
```

### Locale warnings (LC_PAPER, LC_NAME)

If you see locale errors for `en_GB.UTF-8`:
```bash
sudo sed -i 's/#en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/' /etc/locale.gen
sudo locale-gen
```

---

## File reference

### Systemd services

| File | Purpose |
|---|---|
| `/usr/lib/systemd/user/plasma-kwin_wayland.service` | Desktop session KWin (no --inputmethod) |
| `/usr/lib/systemd/user/plasma-login-kwin_wayland.service` | Greeter KWin (base, ships with maliit-keyboard) |
| `/etc/systemd/user/plasma-login-kwin_wayland.service.d/override.conf` | Greeter override (changes to plasma-keyboard) |
| `/usr/lib/systemd/system/plasmalogin.service` | Display manager service |

### Configuration

| File | Purpose |
|---|---|
| `/etc/environment` | `KWIN_IM_SHOW_ALWAYS=1` |
| `/etc/plasmalogin.conf` | plasmalogin config (autologin, session type) |
| `/var/lib/plasmalogin/.config/kdeglobals` | Greeter color scheme (BreezeDark for dark keyboard) |
| `~/.config/kwinrc` | KWin config (NOTE: `[Wayland] InputMethod=` is NOT read by the wrapper) |

### Binaries

| Binary | Purpose |
|---|---|
| `/usr/bin/plasma-keyboard` | Virtual keyboard for greeter (zwp_input_method_v1) |
| `/usr/bin/kwin_wayland` | KDE Wayland compositor |
| `/usr/bin/kwin_wayland_wrapper` | Wrapper that sets up sockets then forwards all args to kwin_wayland |
| `/usr/lib/plasma-login-greeter` | plasmalogin greeter binary |

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
- **Greeter (login screen)**: plasma-keyboard via `--inputmethod` (required
  because the greeter runs under the `plasmalogin` system user which cannot use
  EIS portal access)
- **Desktop session**: clawier via layer-shell + EIS (no `--inputmethod` needed,
  user-space, more flexible)

Do NOT add `--inputmethod` to the desktop session unless you want BOTH keyboards
to potentially appear.
