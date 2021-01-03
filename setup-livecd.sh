#!/bin/sh

#
# Gentoo auto system configurator script. Run this within Archlinux's live CD environment.
#

echo ":: Welcome to Gentoo system configurator"
echo ":: Installing script dependencies"
pacman -Sy --needed --noconfirm \
    fzf \
    git \
    wget

echo
echo ":: Fetching gen-orbit repository"
cd ~
git clone https://github.com/paultoliver/gen-orbit
cd gen-orbit

echo
echo ":: Please provide the following information"
read -p "-- Hostname for your new system: " hostname
read -p "-- Username for daily use: " username
stty -echo
read -p "-- System password: " password && echo
read -p "-- Confirm password: " password_confirm && echo
stty echo

[ "$password" != "$password_confirm" ] && { echo "!! Passwords do not match. Aborting."; exit 1; }

drive=$(lsblk -lp | grep disk | awk '{print $1}' | fzf -1 --reverse --prompt="-- Select installation drive: ")
timezone=$(timedatectl list-timezones | fzf --reverse --prompt="-- Select timezone: ")
locale=$(grep -E "^#?[a-z]{2,3}_" /etc/locale.gen | sed 's/^#//g' | fzf --reverse --prompt="-- Select locale: ")
keymap=$(localectl list-keymaps | fzf --reverse --prompt="-- Select keymap: ")
mirror=$(lynx -dump https://www.gentoo.org/downloads/mirrors/ | grep -sE "http.*https?://.*$" | grep -osE "https?://.*$" | sed 's/\/$//g' | fzf --reverse --prompt="-- Select mirror: ")

echo
echo ":: The following setup has been selected"
echo ":: Hostname: $hostname"
echo ":: Username: $username"
echo ":: Drive: $drive"
echo ":: Timezone: $timezone"
echo ":: Locale: $locale"
echo ":: Keymap: $keymap"
echo ":: Mirror: $mirror"
echo "!! Warning: all data on selected drive $drive will be wiped permanently!"
read -p "-- To proceed, type yes in capital letters: " proceed
[ "$proceed" != "YES" ] && { echo "!! Aborting."; exit 1; }

echo
echo ":: Formatting disk drive $drive"
sgdisk --zap-all $drive
sgdisk -n 0:0:+512MiB -t 0:ef00 -c 0:boot $drive
sgdisk -n 0:0:0 -t 0:8300 -c 0:root $drive

boot=$(lsblk -lp | grep part | awk '{print $1}' | sed -n '1p')
root=$(lsblk -lp | grep part | awk '{print $1}' | sed -n '2p')

echo
echo ":: Encrypting root partition"
mkdir /run/cryptsetup
echo -n "$password" | cryptsetup luksFormat $root --label=root -d -
echo -n "$password" | cryptsetup open $root luks -d -

echo
echo ":: Formatting partitions"
mkfs.vfat -F 32 -n EFI $boot
mkfs.ext4 -L ROOT /dev/mapper/luks

echo
echo ":: The following layout has been generated"
lsblk -pT --output=NAME,SIZE,TYPE,FSTYPE,UUID $drive
mount /dev/mapper/luks /mnt
mkdir /mnt/boot
mkdir /mnt/gen-orbit
mount $boot /mnt/boot
mount --bind . /mnt/gen-orbit

echo
echo ":: Installing stage3 tarball"
stage3tar=$(lynx -dump $mirror/releases/amd64/autobuilds/current-stage3-amd64-systemd/ | grep -osE "stage3-amd64-systemd-.*\.tar\.xz" | head -n 1)
cd /mnt
while true; do
    wget -T 15 -c $mirror/releases/amd64/autobuilds/current-stage3-amd64-systemd/$stage3tar && break
done
tar xpf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner
rm stage3-*.tar.xz

echo
echo ":: Copying portage configuration files"
cd ~/gen-orbit
mkdir -p /mnt/etc/portage/repos.conf
cp -v /mnt/usr/share/portage/config/repos.conf /mnt/etc/portage/repos.conf/gentoo.conf
cp -v make.conf /mnt/etc/portage/make.conf
sed -i "s@^#GENTOO_MIRRORS=.*\$@GENTOO_MIRRORS=\"$mirror\"@" /mnt/etc/portage/make.conf

echo
echo ":: Generating new fstab"
genfstab -U /mnt > /mnt/etc/fstab

echo
echo ":: Chrooting into new system"
cp -v /etc/resolv.conf /mnt/etc/resolv.conf
arch-chroot /mnt /gen-orbit/setup-chroot.sh \
    "$locale" "$keymap" "$timezone" "$hostname" "$root" "$username" "$password"

echo
echo ":: Done!"
echo ":: Type 'reboot' to log into new user account"
