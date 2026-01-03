#!/bin/bash
set -e

apt-get install -y squashfs-tools rsync

cd /builder

# Create working dirs
mkdir -p mnt_iso edit

# Mount the ISO
mount -o loop ubuntu-22.04.5-desktop-amd64.iso mnt_iso

# Unsquash the live root filesystem directly into edit/
unsquashfs -f -d edit mnt_iso/casper/filesystem.squashfs

# You now have a full Ubuntu rootfs under ./edit
ls edit

umount mnt_iso

# Bind /dev and /run; /proc and /sys are optional but usually helpful
mount --bind /dev  edit/dev
mount --bind /run  edit/run
mount -t proc /proc edit/proc
mount --bind /sys  edit/sys

# Copy DNS config into the chroot
#cp /etc/resolv.conf edit/etc/resolv.conf

chroot edit /bin/bash -c "apt-get update && apt-get install neovim -y; apt-get clean"

umount -lf "edit/dev" || true
umount -lf "edit/run" || true
umount -lf "edit/proc" || true
umount -lf "edit/sys" || true


