# Bluetooth RTL8852 — random disconnect fix

## Symptôme

Souris Bluetooth (Razer Basilisk X HyperSpeed) se déconnecte au hasard.
Seul `sudo systemctl restart bluetooth` la récupère.

## Cause

Carte combo **AzureWave RTL8852CE** (WiFi `rtw89_8852ce`) + **RTL8852CU**
(Bluetooth `btusb`/`btrtl`), même puce partagée.

Signature kernel :

```
Bluetooth: hci0: Opcode 0x0406 failed: -107   # HCI_Disconnect -> ENOTCONN, controller wedge
xHC error in resume, USBSTS 0x401, Reinit     # bug réveil-veille, re-énumère l'USB
```

Le power-management ASPM L1ss du driver WiFi `rtw89_pci` perturbe le lien BT
partagé → drops récurrents + controller figé. Cause documentée #1 de ce chip.

## Fix

Fichiers tracés dans le repo (déploiement manuel, root-owned) :

| Repo | Cible | Rôle |
|------|-------|------|
| `system/etc/modprobe.d/rtw89.conf` | `/etc/modprobe.d/rtw89.conf` | Désactive ASPM L1/L1ss + ps_mode rtw89 |
| `system/etc/udev/rules.d/81-bluetooth-rtl8852.rules` | `/etc/udev/rules.d/` | Garde la radio BT allumée après resume |

Déploiement :

```bash
sudo cp ~/.dotfiles/system/etc/modprobe.d/rtw89.conf /etc/modprobe.d/
sudo cp ~/.dotfiles/system/etc/udev/rules.d/81-bluetooth-rtl8852.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo reboot   # rtw89 en usage, reload module messy
```

Pré-existant : `/etc/modprobe.d/btusb.conf` → `options btusb enable_autosuspend=0`.

## Si drops persistent après reboot

1. `sudo pacman -Syu` — fixes RTL8852 btusb/rtw89 continus dans kernel/firmware.
2. Ajouter `disable_clkreq=Y` à la ligne `rtw89_pci`.

## Vérif

```bash
journalctl -b -k | grep -iE "rtw89|hci0|0x0406"   # plus de wedge "Opcode 0x0406 failed"
cat /sys/module/rtw89_pci/parameters/disable_aspm_l1ss   # -> Y
```
