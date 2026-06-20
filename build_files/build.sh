#!/bin/bash

set -ouex pipefail

### Install packages

dnf5 copr enable -y varlad/zellij
dnf5 copr enable -y ryanabx/cosmic-epoch
dnf5 copr enable -y leloubil/wl-clip-persist
dnf5 install -y --setopt=install_weak_deps=False alacritty fira-code-fonts zellij cosmic-desktop wl-clip-persist grim

### Install Nix
dnf5 install -y --setopt=install_weak_deps=False nix
cat > /usr/lib/systemd/system/nix-daemon.socket << 'EOF'
[Unit]
Description=Nix Daemon Socket
Before=multi-user.target

[Socket]
ListenStream=/nix/var/nix/daemon-socket/socket

[Install]
WantedBy=sockets.target
EOF

cat > /usr/lib/systemd/system/nix-daemon.service << 'EOF'
[Unit]
Description=Nix Daemon
Documentation=man:nix-daemon https://nixos.org/manual
After=network.target

[Service]
ExecStart=/usr/bin/nix-daemon --daemon
KillMode=process
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
Also=nix-daemon.socket
EOF

mkdir -p /etc/nix
echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

systemctl enable nix-daemon.socket

# Switch to cosmic greeter
systemctl disable gdm
systemctl enable cosmic-greeter

