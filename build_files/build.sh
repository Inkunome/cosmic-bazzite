#!/bin/bash

set -ouex pipefail

### Install packages

dnf5 copr enable -y varlad/zellij
dnf5 copr enable -y ryanabx/cosmic-epoch
dnf5 install -y --setopt=install_weak_deps=False alacritty fira-code-fonts zellij cosmic-desktop

### Install Nix
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | \
  sh -s -- install linux \
  --no-confirm \
  --init none \
  --extra-conf "filter-syscalls = false"

systemctl enable nix-daemon

# Switch to cosmic greeter
systemctl disable gdm
systemctl enable cosmic-greeter

