#!/bin/bash
set -e

set_env() {
  ORIG_ISO=ubuntu-22.04.5-desktop-amd64.iso
  WORKDIR="/builder"
  BUILDER=$WORKDIR
  ISO_MNT="$BUILDER/mnt_iso"
  EDIT="$BUILDER/edit"
  ISO_ORIG="$BUILDER/iso_orig"
  ISO_NEW="$BUILDER/iso_new"
  NEW_ISO_NAME=ubuntu-22.04.5-custom.iso

  mkdir -p "$BUILDER" "$ISO_MNT" "$EDIT" "$ISO_ORIG" "$ISO_NEW"
}

open_and_copy_iso_content() {
  cd "$BUILDER"

  # 1. Mount original ISO, copy contents, unsquash filesystem
  # Mount the ISO
  mount -o loop "$WORKDIR/$ORIG_ISO" "$ISO_MNT"

  # Copy everything out of the ISO to iso_orig
  rsync -aHAX "$ISO_MNT"/ "$ISO_ORIG"/

  # Unsquash the live root filesystem into ./edit
  unsquashfs -f -d "$EDIT" "$ISO_MNT/casper/filesystem.squashfs"

  # Unmount ISO
  umount "$ISO_MNT"
}

# Setup chroot
run_chroot () {
  mount --bind /dev "$EDIT/dev"
  mount --bind /run "$EDIT/run"
  mount -t proc /proc "$EDIT/proc"
  mount --bind /sys "$EDIT/sys"

  chroot "$EDIT" /bin/bash -c "cat /etc/os-release"
  chroot "$EDIT" /bin/bash -c "apt-get clean && rm -rf /var/lib/apt/lists/*"

  umount -lf "$EDIT/dev" || true
  umount -lf "$EDIT/run" || true
  umount -lf "$EDIT/proc" || true
  umount -lf "$EDIT/sys" || true
}

# Setup new ISO tree
prepare_new_iso() {
  rsync -aHAX "$ISO_ORIG"/ "$ISO_NEW"/

  # Remove old squashfs to avoid confusion
  rm -f "$ISO_NEW/casper/filesystem.squashfs"

  # Rebuild filesystem.squashfs from ./edit
  mksquashfs "$EDIT" "$ISO_NEW/casper/filesystem.squashfs" \
    -noappend -comp xz

  # Generate manifest inside the edited root
  chroot "$EDIT" /bin/bash -c \
    "dpkg-query -W -f='\${Package} \${Version}\n'" \
    > "$ISO_NEW/casper/filesystem.manifest"

  # Desktop manifest
  cp "$ISO_NEW/casper/filesystem.manifest" \
    "$ISO_NEW/casper/filesystem.manifest-desktop"

  # Optionally strip some packages from the desktop manifest (ubiquity, casper, etc.)
  # sed -i '/ubiquity/d;/casper/d;/discover/d' \
  #   "$ISO_NEW/casper/filesystem.manifest-desktop"

  # Generate filesystem.size
  printf $(du -sx --block-size=1 "$EDIT" | cut -f1) \
    > "$ISO_NEW/casper/filesystem.size"

  # Calculate md5sum.txt
  (
    cd "$ISO_NEW"
    rm -f md5sum.txt
    find . -type f -print0 | \
      xargs -0 md5sum | \
      grep -v isolinux.bin | \
      grep -v boot.cat \
      > md5sum.txt
  )
}

# Build custom ISO
build_new_iso() {
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

  mv $WORKDIR/$NEW_ISO_NAME /output/$NEW_ISO_NAME
  echo "New ISO created at: /output/$NEW_ISO_NAME"
}

set_env
open_and_copy_iso_content
run_chroot
prepare_new_iso
build_new_iso