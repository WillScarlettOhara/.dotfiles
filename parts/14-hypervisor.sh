#!/bin/bash
# parts/14-hypervisor.sh — Prepare hypervisor, mount points, and VMs

echo ""
echo "🖥️  Préparation de l'hyperviseur et des mounts..."

sudo mkdir -p /mnt/calibreweb /mnt/torrent /mnt/2TB /mnt/samba/data
sudo chown "$USER:$USER" /mnt/calibreweb /mnt/torrent
sudo mkdir -p /etc/samba

VIRTIO_ISO="/var/lib/libvirt/images/virtio-win.iso"
if [ ! -f "$VIRTIO_ISO" ]; then
  sudo wget -q https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso -O "$VIRTIO_ISO"
  sudo chmod 644 "$VIRTIO_ISO"
fi

sudo systemctl daemon-reload
for mnt in mnt-calibreweb.mount mnt-torrent.mount; do
  if [ -f "/etc/systemd/system/$mnt" ]; then
    sudo systemctl enable --now "$mnt" 2>/dev/null || true
  fi
done

sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt,kvm "$USER"
if [ -f "/etc/libvirt/qemu/win11.xml" ]; then
  sudo chown root:root "/var/lib/libvirt/images/win11.qcow2" 2>/dev/null || true
  sudo virsh define "/etc/libvirt/qemu/win11.xml" 2>/dev/null || true
fi

if [ -f /etc/fstab ] && grep -q "ntfs3\|cifs" /etc/fstab 2>/dev/null; then
  sudo mount -a 2>/dev/null || true
fi