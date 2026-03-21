#!/bin/bash

set -ouex pipefail

### Install packages

dnf5 copr enable -y swayfx/swayfx
dnf5 copr enable -y varlad/zellij
dnf5 install -y swayfx kanshi alacritty wofi fira-code-fonts zellij waybar blueman pavucontrol

curl -fsSL https://install.determinate.systems/nix | sh -s -- install ostree --no-confirm

# Clear cache
dnf5 clean all 
rm -rf /var/cache/dnf/*

# Switch to cosmic greeter
# systemctl disable isplay-manager 
# systemctl enable cosmic-greeter.service -f

