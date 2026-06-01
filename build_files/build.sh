#!/bin/bash

set -ouex pipefail

### Install packages

dnf5 copr enable -y varlad/zellij
dnf5 copr enable -y ryanabx/cosmic-epoch
dnf5 install -y --setopt=install_weak_deps=False alacritty fira-code-fonts zellij cosmic-desktop

mkdir -p /nix

# Switch to cosmic greeter
systemctl disable gdm
systemctl enable cosmic-greeter

