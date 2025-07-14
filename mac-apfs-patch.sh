#!/bin/bash

# NOTE: This script must be run on macOS

set -e

[ ! -f QEMUAppleSilicon/build/nvme.1 ] || cd QEMUAppleSilicon/build

[ -f nvme.1 ] || {
  echo "APFS not found. Exiting..."
  exit 1
}

# Mount the APFS with read/write access
hdiutil attach -imagekey diskimage-class=CRawDiskImage -blocksize 4096 nvme.1
sudo diskutil enableownership /Volumes/System
sudo mount -urw /Volumes/System

# Patch the Dyld Shared Cache
cd /Volumes/System/System/Library/Caches/com.apple.dyld
sudo cp dyld_shared_cache_arm64e dyld_shared_cache_arm64e.orig
sudo bash -c "$(curl -s https://raw.githubusercontent.com/ChefKissInc/QEMUAppleSiliconTools/master/PatchDYLD.sh)" # Use PatchDYLD.fish for fish shell
cd

# Disable the Problematic Launch Services
sudo cp /Volumes/System/System/Library/xpc/launchd.plist /Volumes/System/System/Library/xpc/launchd.plist.orig
sudo plutil -convert xml1 /Volumes/System/System/Library/xpc/launchd.plist

services=(
  "com.apple.voicemail.vmd"
  "com.apple.CommCenter"
  "com.apple.locationd"
)

for s in "${services[@]}"
do
  esc_full=$(printf '%s\n' "/System/Library/LaunchDaemons/$s.plist" | sed 's:/:\\/:g')

  sudo sed -i '' "/<key>${esc_full}<\/key>/ {
    n
    /<dict>/ {
      n
      i\\
$(printf '\t\t\t')<key>Disabled</key>\\
$(printf '\t\t\t')<true/>
    }
  }" /Volumes/System/System/Library/xpc/launchd.plist
done

diskutil eject /Volumes/System

echo "APFS successfully patched."
