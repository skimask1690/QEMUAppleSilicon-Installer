#!/usr/bin/bash

# Prepare the environment
set -e

pacman -Sy --needed --noconfirm base-devel libtool libzip autoconf automake pkg-config git wget unzip python python-pyasn1 python-pyasn1-modules libplist libusbmuxd libimobiledevice-glue libimobiledevice usbmuxd

wget -c https://updates.cdn-apple.com/2020SummerSeed/fullrestores/001-35886/5FE9BE2E-17F8-41C8-96BB-B76E2B225888/iPhone11,8,iPhone12,1_14.0_18A5351d_Restore.ipsw
[ -f BuildManifest.plist ] || unzip iPhone11,8,iPhone12,1_14.0_18A5351d_Restore.ipsw BuildManifest.plist
[ -f ticket.shsh2 ] || wget https://raw.githubusercontent.com/ChefKissInc/QEMUAppleSiliconTools/master/ticket.shsh2
[ -f root_ticket.der ] || python3 -c "$(curl -s https://raw.githubusercontent.com/ChefKissInc/QEMUAppleSiliconTools/master/create_apticket.py)" n104ap BuildManifest.plist ticket.shsh2 root_ticket.der

if ! idevicerestore -v 2>&1 | grep -q lib
then
  for repo in libtatsu libirecovery idevicerestore
  do
    if [ ! -d $repo ]
	then
      git clone https://github.com/libimobiledevice/$repo
    fi

    cd $repo

    if [[ $repo == "idevicerestore" ]]
	then
      wget -c https://github.com/user-attachments/files/20678871/idevicerestore.patch
      git apply --reject idevicerestore.patch || true
    fi

    PKG_CONFIG_PATH=/usr/local/lib/pkgconfig/ ./autogen.sh
    make -j$(nproc)
    sudo make install
    cd ..
    rm -rf $repo
  done
fi

# Start the restore
idevicerestore --erase --restore-mode -i 0x1122334455667788 iPhone11,8,iPhone12,1_14.0_18A5351d_Restore.ipsw -T root_ticket.der
