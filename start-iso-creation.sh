#!/bin/bash

sudo pacman -S squashfs-tools

mkdir -p ubuntu-iso-work/{iso,edit,squashfs}
cd ubuntu-iso-work

cp .iso .


sudo mount -o loop .iso iso

sudo unsquashfs -d squashfs iso/casper/filesystem.squashfs

sudo cp -a squashfs tmp-fs

sudo mount --bind /dev tmp-fs/dev
sudo mount --bind /run tmp-fs/run
sudo mount -t proc /proc tmp-fs/proc
sudo mount -t sysfs /sys tmp-fs/sys
sudo mount -t devpts /dev/pts tmp-fs/dev/pts
sudo cp /etc/resolv.conf tmp-fs/etc/resolv.conf

sudo chroot tmp-fs /bin/bash

##########################
#  add your changes here #
##########################


# existing to tmp-fs
sudo umount tmp-fs/dev/pts
sudo umount tmp-fs/dev
sudo umount tmp-fs/proc
sudo umount tmp-fs/sys
sudo umount tmp-fs/run

# rebuild squashfs
sudo rm -f iso/casper/filesystem.squashfs

sudo mksquashfs tmp-fs iso/casper/filesystem.squashfs -b 1048576 -comp xz -Xbcj x86

# Manifest (list of packages)
sudo chroot edit dpkg-query -W --showformat='${Package} ${Version}\n' \
  | sudo tee iso/casper/filesystem.manifest

# Remove live-only packages from manifest-desktop if needed
sudo cp iso/casper/filesystem.manifest iso/casper/filesystem.manifest-desktop
sudo sed -i '/ubiquity/d;/casper/d;/discover/d;/laptop-detect/d;/os-prober/d' \
  iso/casper/filesystem.manifest-desktop

# Size file (if present)
printf $(sudo du -sx --block-size=1 edit | cut -f1) | sudo tee iso/casper/filesystem.size





cd iso

# Many Ubuntu ISOs use isolinux for BIOS and GRUB for UEFI; adjust paths if different.

sudo xorriso \
  -as mkisofs \
  -r -V "CustomUbuntu" \
  -o ../ubuntu-custom.iso \
  -J -l -cache-inodes \
  -isohybrid-mbr isolinux/isohdpfx.bin \
  -partition_offset 16 \
  -b isolinux/isolinux.bin \
     -c isolinux/boot.cat \
     -no-emul-boot -boot-load-size 4 -boot-info-table \
  -eltorito-alt-boot \
     -e boot/grub/efi.img \
     -no-emul-boot \
  .


cd ..
sudo umount iso
