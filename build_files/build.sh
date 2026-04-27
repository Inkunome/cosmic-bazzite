#!/bin/bash

set -ouex pipefail

### Install packages

dnf5 copr enable -y varlad/zellij
dnf5 copr enable -y ryanabx/cosmic-epoch 
dnf5 install -y alacritty fira-code-fonts zellij waybar blueman pavucontrol
# dnf5 install -y cosmic-desktop

curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | \
    sh -s -- install ostree \
    --extra-conf "filter-syscalls = false" \
    --no-start-daemon \
    --no-confirm

# Clear cache
dnf5 clean all 
rm -rf /var/cache/dnf/*

# Switch to cosmic greeter
# systemctl disable gdm
# systemctl enable cosmic-greeter

