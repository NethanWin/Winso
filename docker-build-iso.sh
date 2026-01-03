#!/bin/bash
set -e

# ============================
# Config
# ============================
ORIG_ISO=ubuntu-22.04.5-desktop-amd64.iso
WORKDIR="/builder"
BUILDER=$WORKDIR
ISO_MNT="$BUILDER/mnt_iso"
EDIT="$BUILDER/edit"
ISO_ORIG="$BUILDER/iso_orig"
ISO_NEW="$BUILDER/iso_new"
NEW_ISO_NAME=ubuntu-22.04.5-custom.iso

mkdir -p "$BUILDER" "$ISO_MNT" "$EDIT" "$ISO_ORIG" "$ISO_NEW"

cd "$BUILDER"

# Install tools (Debian/Ubuntu host)

# ============================
# 1. Mount original ISO, copy contents, unsquash filesystem
# ============================
# Mount the ISO
mount -o loop "$WORKDIR/$ORIG_ISO" "$ISO_MNT"

# Copy everything out of the ISO to iso_orig
rsync -aHAX "$ISO_MNT"/ "$ISO_ORIG"/

# Unsquash the live root filesystem into ./edit
unsquashfs -f -d "$EDIT" "$ISO_MNT/casper/filesystem.squashfs"

# Show that we have a full Ubuntu rootfs
ls "$EDIT"

# Unmount ISO
umount "$ISO_MNT"

# ============================
# 2. Prepare chroot and customize
# ============================
# Bind /dev and /run; /proc and /sys are optional but helpful
mount --bind /dev "$EDIT/dev"
mount --bind /run "$EDIT/run"
mount -t proc /proc "$EDIT/proc"
mount --bind /sys "$EDIT/sys"

# Copy DNS config into the chroot if needed
# cp /etc/resolv.conf "$EDIT/etc/resolv.conf"

# Enter chroot and run whatever customization commands you want.
# Example: just print os-release to show it's working.
chroot "$EDIT" /bin/bash -c "cat /etc/os-release"

# === YOUR CUSTOMIZATION AREA ===
# Example:
# chroot "$EDIT" /bin/bash -c "
#   apt-get update &&
#   apt-get install -y vim &&
#   useradd -m customuser &&
#   echo 'customuser:password' | chpasswd
# "

# When done customizing, clean up apt cache (optional but recommended)
chroot "$EDIT" /bin/bash -c "apt-get clean"

# ============================
# 3. Unmount chroot bind mounts
# ============================
umount -lf "$EDIT/dev" || true
umount -lf "$EDIT/run" || true
umount -lf "$EDIT/proc" || true
umount -lf "$EDIT/sys" || true

# ============================
# 4. Prepare new ISO tree
# ============================
# Start from original ISO tree
rsync -aHAX "$ISO_ORIG"/ "$ISO_NEW"/

# Remove old squashfs to avoid confusion
rm -f "$ISO_NEW/casper/filesystem.squashfs"

# ============================
# 5. Rebuild filesystem.squashfs from ./edit
# ============================
mksquashfs "$EDIT" "$ISO_NEW/casper/filesystem.squashfs" \
  -noappend -comp xz

# ============================
# 6. Regenerate manifest
# ============================
# Generate manifest inside the edited root
chroot "$EDIT" /bin/bash -c \
  "dpkg-query -W -f='\${Package} \${Version}\n'" \
  > "$ISO_NEW/casper/filesystem.manifest"

# Desktop manifest (Ubuntu live convention)
cp "$ISO_NEW/casper/filesystem.manifest" \
   "$ISO_NEW/casper/filesystem.manifest-desktop"

# Optionally strip some packages from the desktop manifest (ubiquity, casper, etc.)
# sed -i '/ubiquity/d;/casper/d;/discover/d' \
#   "$ISO_NEW/casper/filesystem.manifest-desktop"

# ============================
# 7. Regenerate filesystem.size
# ============================
printf $(du -sx --block-size=1 "$EDIT" | cut -f1) \
  > "$ISO_NEW/casper/filesystem.size"

# ============================
# 8. Recalculate md5sum.txt
# ============================
(
  cd "$ISO_NEW"
  rm -f md5sum.txt
  find . -type f -print0 | \
    xargs -0 md5sum | \
    grep -v isolinux.bin | \
    grep -v boot.cat \
    > md5sum.txt
)

# ============================
# 9. Build new ISO (BIOS + UEFI)
# ============================
cd "$ISO_NEW"

xorriso \
  -as mkisofs \
  -iso-level 3 \
  -full-iso9660-filenames \
  -volid "Ubuntu 22.04.5 Custom" \
  -output "/builder/ubuntu-22.04.5-custom.iso" \
  -eltorito-boot boot/grub/i386-pc/eltorito.img \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
  -eltorito-alt-boot \
    -e EFI/boot/bootx64.efi \
    -no-emul-boot \
  .

echo "New ISO created at: $WORKDIR/$NEW_ISO_NAME"
mv $WORKDIR/$NEW_ISO_NAME /output/$NEW_ISO_NAME
