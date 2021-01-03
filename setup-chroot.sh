#!/bin/sh

#
# Gentoo auto system configurator script. Run this within chrooted environment.
#

locale=$1
keymap=$2
timezone=$3
hostname=$4
root=$5
username=$6
password=$7

. /etc/profile

echo
echo ":: Configuring locale"
echo "$locale" > /etc/locale.gen
echo "LANG=$(echo $locale | awk '{print $1}')" > /etc/locale.conf
echo "KEYMAP=$keymap" > /etc/vconsole.conf
locale-gen

echo
echo ":: Configuring time and date"
ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
systemctl enable systemd-timesyncd.service

echo
echo ":: Configuring hostname"
echo "$hostname" > /etc/hostname
cat <<EOF > /etc/hosts
127.0.0.1 localhost
::1       localhost
127.0.0.1 $hostname.localdomain $hostname
EOF

echo
echo ":: Emerging world set"
echo ":: Go grab a cup of coffee :)"
mkdir -p /var/db/repos/gentoo
emerge-webrsync -q
emerge -1q sys-apps/portage
emerge -quDN @world

echo
echo ":: Building the kernel"
emerge -q sys-kernel/gentoo-sources
cp -v /gen-orbit/kernel.conf /usr/src/linux/.config
cd /usr/src/linux
make
make modules_install
make install
cd /

echo
echo ":: Emerging some other dependencies"
emerge -nq \
    app-admin/doas \
    app-arch/lz4 \
    app-arch/lzop \
    app-portage/flaggie \
    app-shells/dash \
    sys-apps/pciutils \
    sys-firmware/intel-microcode \
    sys-fs/cryptsetup \
    sys-fs/e2fsprogs \
    sys-kernel/genkernel \
    sys-libs/efivar

# Uncomment this when installing on laptops that need WIFI support
#emerge -nq sys-kernel/linux-firmware

echo
echo ":: Setting dash as default system shell"
ln -sf /bin/dash /bin/sh

echo
echo ":: Enabling network manager"
flaggie net-misc/networkmanager -ofono -ppp -vala -wext
flaggie net-wireless/wpa_supplicant +dbus
emerge -nq net-misc/networkmanager
systemctl enable NetworkManager.service

echo
echo ":: Configuring bootloader"
sed -i 's/^#MAKEOPTS=.*$/MAKEOPTS="\$(portageq envvar MAKEOPTS)"/' /etc/genkernel.conf
sed -i 's/^#LUKS=.*$/LUKS="yes"/' /etc/genkernel.conf
genkernel --install --luks --kernel-config=/usr/src/linux/.config initramfs
bootctl install
echo "default gentoo.conf" > /boot/loader/loader.conf
vmlinuz=$(basename $(ls /boot/vmlinuz*))
iucode=$(basename $(ls /boot/intel-uc*))
initramfs=$(basename $(ls /boot/initramfs*))
cat <<EOF > /boot/loader/entries/gentoo.conf
title Gentoo
linux /$vmlinuz
initrd /$iucode
initrd /$initramfs
options crypt_root=UUID=$(blkid -s UUID -o value $root) root=/dev/mapper/root rw quiet systemd.show_status=false
EOF

echo
echo ":: Configuring root and daily user $username"
useradd -m -G audio,users,wheel -s /bin/bash $username
echo "root:$password" | chpasswd
echo "$username:$password" | chpasswd
echo "permit nopass keepenv $username" > /etc/doas.conf

echo
echo ":: Setting up auto-login for user $username"
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat <<EOF > /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
Type=simple
ExecStart=
ExecStart=-/sbin/agetty --autologin $username --noclear %I 38400 linux
EOF

echo
echo ":: Opening subshell"
echo ":: Revise everything is OK within chroot and hit C^c to exit"
/bin/bash
