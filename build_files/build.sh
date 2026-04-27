#!/bin/bash

set -ouex pipefail

### Install packages

dnf5 copr enable -y varlad/zellij
dnf5 install -y alacritty fira-code-fonts zellij waybar blueman pavucontrol

curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | \
    sh -s -- install ostree \
    --extra-conf "filter-syscalls = false" \
    --init none \
    --no-confirm

# Clear cache
dnf5 clean all 
rm -rf /var/cache/dnf/*

# Switch to cosmic greeter
# systemctl disable isplay-manager 
# systemctl enable cosmic-greeter.service -f

