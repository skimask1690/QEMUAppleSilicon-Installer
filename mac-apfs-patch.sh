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
sudo cp /Volumes/System/System/Library/xpc/launchd.plist /Volumes/System/System/Library/xpc/launchd.plist.orig
sudo plutil -convert xml1 /Volumes/System/System/Library/xpc/launchd.plist

services=(
  "com.apple.voicemail.vmd"
  "com.apple.CommCenter"
  "com.apple.locationd"
)

for s in "${services[@]}"
do
  esc_s=$(printf '%s\n' "/System/Library/LaunchDaemons/$s.plist" | sed 's:/:\\/:g')

  sudo sed -i '' "/<key>${esc_s}<\/key>/ {
    n
    /<dict>/ {
      n
      i\\
<key>Disabled</key>\\
<true/>
    }
  }" /Volumes/System/System/Library/xpc/launchd.plist
done

cd
diskutil eject /Volumes/System

echo "APFS successfully patched."
