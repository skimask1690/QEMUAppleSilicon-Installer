#!/bin/bash

[ $EUID -ne 0 ] || {
  echo "This script should not be run as root. It will request elevated privileges when necessary."
  exit 1
}

# Prepare the environment
set -e
sudo apt-get update
sudo apt-get install -y build-essential libtool meson ninja-build pkg-config libcapstone-dev device-tree-compiler libglib2.0-dev gnutls-bin libjpeg-turbo8-dev libpng-dev libslirp-dev libssh-dev libusb-1.0-0-dev liblzo2-dev libncurses5-dev libpixman-1-dev libsnappy-dev vde2 zstd libgnutls28-dev libgmp10 libgmp3-dev lzfse liblzfse-dev libgtk-3-dev libsdl2-dev git make unzip curl python3-venv python3-pyasn1 python3-pyasn1-modules

if grep -q '3.10.1' /usr/local/lib64/pkgconfig/nettle.pc 2>/dev/null
then
  export PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig

elif ! [ "$(pkg-config --modversion nettle)" = "3.10.1" ]
then
  wget -c https://ftp.gnu.org/gnu/nettle/nettle-3.10.1.tar.gz
  tar -xf nettle-3.10.1.tar.gz
  cd nettle-3.10.1
  ./configure
  make -j$(nproc)
  sudo make install
  cd ..
  rm -rf nettle-3.10.1.tar.gz nettle-3.10.1
  export PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig
fi

# Host setup
if [ -d ../../QEMUAppleSilicon/build ]
then
  :
elif [ -d QEMUAppleSilicon/build ]
then
  cd QEMUAppleSilicon/build
elif [ ! -d QEMUAppleSilicon ]
then
  git clone https://github.com/ChefKissInc/QEMUAppleSilicon
  cd QEMUAppleSilicon
  git submodule update --init
  mkdir build
  cd build
  ../configure --target-list=aarch64-softmmu,x86_64-softmmu --enable-lzfse --enable-slirp --enable-capstone --enable-curses --enable-libssh --enable-virtfs --enable-zstd --enable-nettle --enable-gnutls --enable-gtk --enable-sdl --disable-werror
  make -j$(nproc)
fi

# Download img4tool
[ -f img4tool ] || {
  wget -c https://github.com/tihmstar/img4tool/releases/download/217/buildroot_ubuntu-latest.zip
  unzip buildroot_ubuntu-latest.zip buildroot_ubuntu-latest/usr/local/bin/img4tool
  chmod +x buildroot_ubuntu-latest/usr/local/bin/img4tool
  mv buildroot_ubuntu-latest/usr/local/bin/img4tool .
  rm -rf buildroot_ubuntu-latest.zip buildroot_ubuntu-latest
}

# Download img4lib
[ -f img4 ] || {
  wget -c https://github.com/xerub/img4lib/releases/download/1.0/img4lib-2020-10-27.tar.gz
  tar -xf img4lib-2020-10-27.tar.gz img4lib-2020-10-27/linux/img4
  [ -f /lib/x86_64-linux-gnu/libcrypto.so.1 ] || sudo ln -s /lib/x86_64-linux-gnu/libcrypto.so /lib/x86_64-linux-gnu/libcrypto.so.1
  mv img4lib-2020-10-27/linux/img4 .
  rm -rf img4lib-2020-10-27.tar.gz img4lib-2020-10-27
}

# Fetch iOS 14.0 beta 5 ipsw for iPhone12,1
[ -d iPhone11_8_iPhone12_1_14.0_18A5351d_Restore ] || {
  wget -c https://updates.cdn-apple.com/2020SummerSeed/fullrestores/001-35886/5FE9BE2E-17F8-41C8-96BB-B76E2B225888/iPhone11,8,iPhone12,1_14.0_18A5351d_Restore.ipsw
  unzip iPhone11,8,iPhone12,1_14.0_18A5351d_Restore.ipsw -d iPhone11_8_iPhone12_1_14.0_18A5351d_Restore -x 038-44337-083.dmg
  rm -f iPhone11,8,iPhone12,1_14.0_18A5351d_Restore.ipsw
}

# Fetch iOS 14.7.1 ipsw for iPhone12,1
[ -f sep-firmware.n104.RELEASE.im4p ] || {
  wget -c https://updates.cdn-apple.com/2021SummerFCS/fullrestores/071-73868/321919C4-1F21-4387-936D-B72374C39DD6/iPhone11,8,iPhone12,1_14.7.1_18G82_Restore.ipsw
  unzip iPhone11,8,iPhone12,1_14.7.1_18G82_Restore.ipsw Firmware/all_flash/sep-firmware.n104.RELEASE.im4p
  mv Firmware/all_flash/sep-firmware.n104.RELEASE.im4p .
  rm -rf iPhone11,8,iPhone12,1_14.7.1_18G82_Restore.ipsw Firmware
}

# Download SHSH blob
[ -f ticket.shsh2 ] || wget https://raw.githubusercontent.com/ChefKissInc/QEMUAppleSiliconTools/master/ticket.shsh2

# Create the SEP ticket
[ -f sep_root_ticket.der ] || python3 -c "$(curl -s https://raw.githubusercontent.com/ChefKissInc/QEMUAppleSiliconTools/master/create_septicket.py)" n104ap iPhone11_8_iPhone12_1_14.0_18A5351d_Restore/BuildManifest.plist ticket.shsh2 sep_root_ticket.der

# Decrypt the firmware
[ -f sep-firmware.n104.RELEASE ] || ./img4tool -e --iv d674398fcc1cae184c97a89c078709a4 --key 55e4dd876cf876adef4a935c8f630e393c386653a2028292f21419df39a04dda -o sep-firmware.n104.RELEASE sep-firmware.n104.RELEASE.im4p

# Format the firmware to IMG4
[ -f sep-firmware.n104.RELEASE.new.img4 ] || {
  ./img4tool -t rsep -d ff86cbb5e06c820266308202621604696d706c31820258ff87a3e8e0730e300c1604747a3073020407e78000ff868bc9da730e300c160461726d73020400d84000ff87a389da7382010e3082010a160474626d730482010036373166326665363234636164373234643365353332633464666361393732373734353966613362326232366635643962323032383061643961303037666635323834393936383138653962303461336434633034393061663833313630633464356330313832396536633635303836313230666133346539663263323165373237316265623231636139386237386464303064363037326530366464393962666163623262616362623261373830613465636161303363326361333930303931636334613461666231623737326238646234623865653566663365636437373135306531626566333633303034336637373665666265313130316538623433ff87a389da7282010e3082010a160474626d720482010034626631393164373134353637356364306264643131616166373734386138663933373363643865666234383830613130353237633938393833666636366538396438333330623730626237623561333530393864653735353265646635373762656166363137353235613831663161393838373838613865346665363734653936633439353066346136366136343231366561356438653333613833653530353962333536346564633533393664353539653337623030366531633637343633623736306336333164393163306339363965366662373130653962333061386131396338333166353565636365393835363331643032316134363361643030 -c sep-firmware.n104.RELEASE.im4p sep-firmware.n104.RELEASE
  ./img4 -F -o sep-firmware.n104.RELEASE.new.img4 -i sep-firmware.n104.RELEASE.im4p -M sep_root_ticket.der
}

# Create the AP Ticket
[ -f root_ticket.der ] || python3 -c "$(curl -s https://raw.githubusercontent.com/ChefKissInc/QEMUAppleSiliconTools/master/create_apticket.py)" n104ap iPhone11_8_iPhone12_1_14.0_18A5351d_Restore/BuildManifest.plist ticket.shsh2 root_ticket.der

# Download the SEP ROM
[ -f AppleSEPROM-Cebu-B1 ] || wget https://securerom.fun/resources/SEPROM/AppleSEPROM-Cebu-B1

# Create the disks
[ -f nvme.1 ]        || ./qemu-img create -f raw nvme.1 16G # Can also be 32G
[ -f nvme.2 ]        || ./qemu-img create -f raw nvme.2 8M
[ -f nvme.3 ]        || ./qemu-img create -f raw nvme.3 128K
[ -f nvme.4 ]        || ./qemu-img create -f raw nvme.4 8K
[ -f nvram ]         || ./qemu-img create -f raw nvram 8K
[ -f nvme.6 ]        || ./qemu-img create -f raw nvme.6 4K
[ -f nvme.7 ]        || ./qemu-img create -f raw nvme.7 1M
[ -f nvme.8 ]        || ./qemu-img create -f raw nvme.8 3M
[ -f sep_nvram ]     || ./qemu-img create -f raw sep_nvram 2K
[ -f sep_ssc ]       || ./qemu-img create -f raw sep_ssc 128K

[ -f archvm.qcow2 ]  || ./qemu-img create -f qcow2 archvm.qcow2 20G

sync

# Download and boot into Arch Linux
wget -c https://mirror.rackspace.com/archlinux/iso/latest/archlinux-x86_64.iso

if [ -e /dev/kvm ]
then
  SU_FLAG="sudo"
  KVM_FLAG="-enable-kvm"
fi
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
