#!/bin/bash

# NOTE: This script must be run on macOS

set -e

[ ! -f QEMUAppleSilicon/build/nvme.1 ] || cd QEMUAppleSilicon/build

[ -f nvme.1 ] || {
  echo "APFS not found. Exiting..."
  exit 1
}

hdiutil attach -imagekey diskimage-class=CRawDiskImage -blocksize 4096 nvme.1
sudo diskutil enableownership /Volumes/System
sudo mount -urw /Volumes/System
cd /Volumes/System/System/Library/Caches/com.apple.dyld
sudo cp dyld_shared_cache_arm64e dyld_shared_cache_arm64e.orig
sudo bash -c "$(curl -s https://raw.githubusercontent.com/ChefKissInc/QEMUAppleSiliconTools/master/PatchDYLD.sh)" # Use PatchDYLD.fish for fish shell

cd
diskutil eject /Volumes/System

echo "APFS successfully patched."