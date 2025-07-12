#!/bin/bash
# Note: apfs-fuse currently supports read-only mounts only.
# This script attempts to mount an APFS partition in read-write mode,
# which is not supported and will not work as intended.

set -e

if [ -d ../../QEMUAppleSilicon/build ]
then
  :
elif [ -d QEMUAppleSilicon/build ]
then
  cd QEMUAppleSilicon/build
fi

[ ! -d apfs-fuse ] || rm -rf apfs-fuse

[ -f apfs-fuse ] || {
  sudo apt-get update
  sudo apt-get install -y build-essential cmake libfuse3-dev zlib1g-dev libbz2-dev git
  git clone https://github.com/sgan81/apfs-fuse
  cd apfs-fuse
  git submodule init
  git submodule update
  mkdir build
  cd build
  cmake ..
  make
  cd ../..
  mv apfs-fuse/build/apfs-fuse .apfs-fuse
  rm -rf apfs-fuse
  mv .apfs-fuse apfs-fuse
}

set +e

LOOP=$(sudo losetup --find --show --partscan --sector-size 4096 nvme.1)
sudo ./apfs-fuse "${LOOP}p1" /mnt
sudo mount -o remount,rw /mnt

sudo umount /mnt
sudo losetup -d /dev/loop0
