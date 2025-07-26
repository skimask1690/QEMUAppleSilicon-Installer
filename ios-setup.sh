#!/bin/bash

# ===== URL VARIABLES =====
NETTLE_URL="https://ftp.gnu.org/gnu/nettle/nettle-3.10.1.tar.gz"
QEMU_GIT_URL="https://github.com/ChefKissInc/QEMUAppleSilicon"
IMG4TOOL_URL="https://github.com/tihmstar/img4tool/releases/download/217/buildroot_ubuntu-latest.zip"
IMG4LIB_URL="https://github.com/xerub/img4lib/releases/download/1.0/img4lib-2020-10-27.tar.gz"
IPSW_14_BETA5_URL="https://updates.cdn-apple.com/2020SummerSeed/fullrestores/001-35886/5FE9BE2E-17F8-41C8-96BB-B76E2B225888/iPhone11,8,iPhone12,1_14.0_18A5351d_Restore.ipsw"
IPSW_14_7_1_URL="https://updates.cdn-apple.com/2021SummerFCS/fullrestores/071-73868/321919C4-1F21-4387-936D-B72374C39DD6/iPhone11,8,iPhone12,1_14.7.1_18G82_Restore.ipsw"
TICKET_URL="https://raw.githubusercontent.com/ChefKissInc/QEMUAppleSiliconTools/master/ticket.shsh2"
SEPTICKET_PY_URL="https://raw.githubusercontent.com/ChefKissInc/QEMUAppleSiliconTools/master/create_septicket.py"
APTICKET_PY_URL="https://raw.githubusercontent.com/ChefKissInc/QEMUAppleSiliconTools/master/create_apticket.py"
SEPROM_URL="https://securerom.fun/resources/SEPROM/AppleSEPROM-Cebu-B1"
ARCHLINUX_ISO_URL="https://mirror.rackspace.com/archlinux/iso/latest/archlinux-x86_64.iso"

[ $EUID -ne 0 ] || {
  echo "This script should not be run as root. It will request elevated privileges when necessary."
  exit 1
}

# Prepare the environment
set -e
sudo apt-get update
sudo apt-get install -y build-essential libtool meson ninja-build pkg-config libcapstone-dev device-tree-compiler libglib2.0-dev gnutls-bin libjpeg-turbo8-dev libpng-dev libslirp-dev libssh-dev libusb-1.0-0-dev liblzo2-dev libncurses5-dev libpixman-1-dev libsnappy-dev vde2 zstd libgnutls28-dev libgmp10 libgmp3-dev lzfse liblzfse-dev libgtk-3-dev libsdl2-dev git make unzip curl python3-venv python3-pyasn1 python3-pyasn1-modules

# Install nettle if missing
if grep -q '3.10.1' /usr/local/lib64/pkgconfig/nettle.pc 2>/dev/null
then
  export PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig
elif ! [ "$(pkg-config --modversion nettle)" = "3.10.1" ]
then
  wget -c "$NETTLE_URL"
  tar -xf nettle-3.10.1.tar.gz
  cd nettle-3.10.1
  ./configure
  make -j$(nproc)
  sudo make install
  cd ..
  rm -rf nettle-3.10.1.tar.gz nettle-3.10.1
  export PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig
fi

# Clone or enter QEMUAppleSilicon
if [ -d ../../QEMUAppleSilicon/build ]
then
  cd ../../QEMUAppleSilicon/build
elif [ -d ../QEMUAppleSilicon/build ]
then
  cd ../QEMUAppleSilicon/build
elif [ -d QEMUAppleSilicon/build ]
then
  cd QEMUAppleSilicon/build
elif [ ! -d QEMUAppleSilicon ]
then
  git clone "$QEMU_GIT_URL"
  cd QEMUAppleSilicon
  git submodule update --init
  mkdir build
  cd build
  ../configure --target-list=aarch64-softmmu,x86_64-softmmu --enable-lzfse --enable-slirp --enable-capstone --enable-curses --enable-libssh --enable-virtfs --enable-zstd --enable-nettle --enable-gnutls --enable-gtk --enable-sdl --disable-werror
  make -j$(nproc)
fi

# Download img4tool
[ -f img4tool ] || {
  wget -c "$IMG4TOOL_URL"
  unzip buildroot_ubuntu-latest.zip buildroot_ubuntu-latest/usr/local/bin/img4tool
  chmod +x buildroot_ubuntu-latest/usr/local/bin/img4tool
  mv buildroot_ubuntu-latest/usr/local/bin/img4tool .
  rm -rf buildroot_ubuntu-latest.zip buildroot_ubuntu-latest
}

# Download img4lib
[ -f img4 ] || {
  wget -c "$IMG4LIB_URL"
  tar -xf img4lib-2020-10-27.tar.gz img4lib-2020-10-27/linux/img4
  [ -f /lib/x86_64-linux-gnu/libcrypto.so.1 ] || sudo ln -s /lib/x86_64-linux-gnu/libcrypto.so /lib/x86_64-linux-gnu/libcrypto.so.1
  mv img4lib-2020-10-27/linux/img4 .
  rm -rf img4lib-2020-10-27.tar.gz img4lib-2020-10-27
}

# Fetch iOS 14.0 beta 5 IPSW
[ -d iPhone11_8_iPhone12_1_14.0_18A5351d_Restore ] || {
  wget -c "$IPSW_14_BETA5_URL"
  unzip iPhone11,8,iPhone12,1_14.0_18A5351d_Restore.ipsw -d iPhone11_8_iPhone12_1_14.0_18A5351d_Restore -x 038-44337-083.dmg
  rm -f iPhone11,8,iPhone12,1_14.0_18A5351d_Restore.ipsw
}

# Fetch iOS 14.7.1 IPSW
[ -f sep-firmware.n104.RELEASE.im4p ] || {
  wget -c "$IPSW_14_7_1_URL"
  unzip iPhone11,8,iPhone12,1_14.7.1_18G82_Restore.ipsw Firmware/all_flash/sep-firmware.n104.RELEASE.im4p
  mv Firmware/all_flash/sep-firmware.n104.RELEASE.im4p .
  rm -rf iPhone11,8,iPhone12,1_14.7.1_18G82_Restore.ipsw Firmware
}

# Download SHSH blob
[ -f ticket.shsh2 ] || wget "$TICKET_URL"

# Create the SEP ticket
[ -f sep_root_ticket.der ] || python3 -c "$(curl -s $SEPTICKET_PY_URL)" n104ap iPhone11_8_iPhone12_1_14.0_18A5351d_Restore/BuildManifest.plist ticket.shsh2 sep_root_ticket.der

# Create the AP ticket
[ -f root_ticket.der ] || python3 -c "$(curl -s $APTICKET_PY_URL)" n104ap iPhone11_8_iPhone12_1_14.0_18A5351d_Restore/BuildManifest.plist ticket.shsh2 root_ticket.der

# Download SEP ROM
[ -f AppleSEPROM-Cebu-B1 ] || wget "$SEPROM_URL"

# Download Arch Linux ISO
wget -c "$ARCHLINUX_ISO_URL"

[ ! -e /dev/kvm ] || {
  SU_FLAG="sudo"
  KVM_FLAG="-enable-kvm"
}

echo "Starting Companion VM (USB server)..."
$SU_FLAG ./qemu-system-x86_64 $KVM_FLAG -m 2G -cdrom archlinux-x86_64.iso \
  -drive file=archvm.qcow2,format=qcow2,if=virtio \
  -nic user,model=virtio-net-pci,hostfwd=tcp::32222-:22 \
  -usb -device usb-ehci,id=ehci -device usb-tcp-remote,conn-type=ipv4,conn-addr=127.0.0.1,conn-port=8030,bus=ehci.0 &

echo "Starting iPhone emulator..."
./qemu-system-aarch64 -M t8030,trustcache=iPhone11_8_iPhone12_1_14.0_18A5351d_Restore/Firmware/038-44135-124.dmg.trustcache,ticket=root_ticket.der,sep-fw=sep-firmware.n104.RELEASE.new.img4,sep-rom=AppleSEPROM-Cebu-B1,kaslr-off=true,usb-conn-type=ipv4,usb-conn-addr=127.0.0.1,usb-conn-port=8030 \
  -kernel iPhone11_8_iPhone12_1_14.0_18A5351d_Restore/kernelcache.research.iphone12b \
  -dtb iPhone11_8_iPhone12_1_14.0_18A5351d_Restore/Firmware/all_flash/DeviceTree.n104ap.im4p \
  -initrd iPhone11_8_iPhone12_1_14.0_18A5351d_Restore/038-44135-124.dmg \
  -append "tlto_us=-1 mtxspin=-1 agm-genuine=1 agm-authentic=1 agm-trusted=1 serial=3 launchd_unsecure_cache=1 wdt=-1" \
  -display sdl,show-cursor=on \
  -smp 7 -m 4G -serial mon:stdio \
  -drive file=sep_nvram,if=pflash,format=raw \
  -drive file=sep_ssc,if=pflash,format=raw \
  -drive file=nvme.1,format=raw,if=none,id=drive.1 -device nvme-ns,drive=drive.1,bus=nvme-bus.0,nsid=1,nstype=1,logical_block_size=4096,physical_block_size=4096 \
  -drive file=nvme.2,format=raw,if=none,id=drive.2 -device nvme-ns,drive=drive.2,bus=nvme-bus.0,nsid=2,nstype=2,logical_block_size=4096,physical_block_size=4096 \
  -drive file=nvme.3,format=raw,if=none,id=drive.3 -device nvme-ns,drive=drive.3,bus=nvme-bus.0,nsid=3,nstype=3,logical_block_size=4096,physical_block_size=4096 \
  -drive file=nvme.4,format=raw,if=none,id=drive.4 -device nvme-ns,drive=drive.4,bus=nvme-bus.0,nsid=4,nstype=4,logical_block_size=4096,physical_block_size=4096 \
  -drive file=nvram,if=none,format=raw,id=nvram -device apple-nvram,drive=nvram,bus=nvme-bus.0,nsid=5,nstype=5,id=nvram,logical_block_size=4096,physical_block_size=4096 \
  -drive file=nvme.6,format=raw,if=none,id=drive.6 -device nvme-ns,drive=drive.6,bus=nvme-bus.0,nsid=6,nstype=6,logical_block_size=4096,physical_block_size=4096 \
  -drive file=nvme.7,format=raw,if=none,id=drive.7 -device nvme-ns,drive=drive.7,bus=nvme-bus.0,nsid=7,nstype=8,logical_block_size=4096,physical_block_size=4096
