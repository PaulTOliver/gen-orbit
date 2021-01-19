#!/bin/sh

#
# Gentoo auto user configurator script. Run this within logged-in user environment.
#

echo ":: Welcome to Gentoo user configurator"
echo ":: Configuring user dependencies"
doas flaggie dev-vcs/git -cgi -cvs -highlight -perforce -subversion -tk
doas flaggie media-libs/libglvnd +X
doas flaggie media-libs/mesa +xa
doas flaggie x11-libs/libdrm +libkms

echo
echo ":: Emerging user dependencies"
doas emerge -nq \
    app-admin/stow \
    app-editors/neovim \
    dev-vcs/git \
    media-fonts/jetbrains-mono \
    media-gfx/feh \
    x11-apps/mesa-progs \
    x11-apps/xinit \
    x11-apps/xrandr \
    x11-apps/xrdb \
    x11-base/xorg-drivers \
    x11-base/xorg-server \
    x11-libs/libX11 \
    x11-libs/libXft \
    x11-libs/libXinerama \
    x11-libs/libXrandr \
    x11-misc/picom

echo
echo ":: Fetching suckless repositories"
mkdir -p ~/suckless
cd ~/suckless
github=https://github.com/paultoliver
git clone --depth 1 --single-branch --branch master $github/dotfiles
git clone --depth 1 --single-branch --branch orbit $github/dmenu
git clone --depth 1 --single-branch --branch orbit $github/dwm
git clone --depth 1 --single-branch --branch orbit $github/slstatus
git clone --depth 1 --single-branch --branch orbit $github/st

echo
echo ":: Building dwm"
cd ~/suckless/dwm
cp -v config.def.h config.h
make && doas make install

echo
echo ":: Building dmenu"
cd ~/suckless/dmenu
cp -v config.def.h config.h
make && doas make install

echo
echo ":: Building slstatus"
cd ~/suckless/slstatus
cp -v config.def.h config.h
make && doas make install

echo
echo ":: Building st"
cd ~/suckless/st
cp -v config.def.h config.h
make && doas make install

echo
echo ":: Stowing dotfiles"
cd ~/suckless/dotfiles
rm -rf ~/.bash*
stow -t ~ bash picom-vbox xorg

echo
echo ":: Done!"
echo ":: Type 'doas reboot' to log into updated environment"
