#!/bin/bash
set -e

parted --script /dev/vda mklabel msdos mkpart primary ext4 1MiB 100%
mkfs.ext4 /dev/vda1
mount /dev/vda1 /mnt
pacstrap /mnt base linux linux-firmware dhcpcd grub
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt /bin/bash -c "
  ln -sf /usr/share/zoneinfo/UTC /etc/localtime
  hwclock --systohc
  echo archvm > /etc/hostname
  passwd -d root
  systemctl enable dhcpcd
  grub-install /dev/vda
  grub-mkconfig -o /boot/grub/grub.cfg
"

umount -R /mnt
reboot
