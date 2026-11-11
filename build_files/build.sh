#!/bin/bash

set -ouex pipefail

COPRS=(
    varlad/zellij
    swayfx/swayfx
    varlad/eww
    leloubil/wl-clip-persist
)

### Install packages

for copr in "${COPRS[@]}"; do
    dnf5 -y copr enable "$copr"
done

dnf5 install -y --setopt=install_weak_deps=False \
    alacritty \
    fira-code-fonts \
    ibm-plex-sans-fonts \
    ibm-plex-mono-fonts \
    zellij \
    wl-clip-persist \
    swayfx \
    eww \
    swaybg \
    swayidle \
    swaylock \
    fuzzel \
    mako \
    grim \
    slurp \
    swappy \
    wl-clipboard \
    cliphist \
    brightnessctl \
    playerctl \
    pavucontrol \
    network-manager-applet \
    blueman \
    mate-polkit \
    kanshi \
    wlr-randr \
    wlogout \
    jq \
    socat \
    xdg-desktop-portal-wlr \
    xdg-desktop-portal-gtk \
    thunar \
    ripgrep \
    fd-find \
    chafa \
    neovim \
    nm-connection-editor \
    wlsunset \
    wdisplays \
    udiskie \
    nix \
    system-config-printer

# Leave the COPRs present but disabled, matching the convention the Bazzite base
# uses for its own COPRs. Enabled COPRs would otherwise be consulted by every
# `dnf`/`bootc usroverlay` operation a user runs on the deployed system.
for copr in "${COPRS[@]}"; do
    dnf5 -y copr disable "$copr"
done

### Nix
## /nix ships in the image, but a deployed bootc system mounts / read-only
## (composefs readonly=true), so the store would be unwritable. Bind-mount the
## store from /var, which is the writable, persistent location on bootc.

# systemd-tmpfiles creates the backing store before anything mounts or uses it.
cat > /usr/lib/tmpfiles.d/zz-nix-bootc.conf << 'EOF'
d /var/nix                       0755 root root   -
d /var/nix/store                 1775 root nixbld -
d /var/nix/var                   0755 root root   -
d /var/nix/var/nix               0755 root root   -
d /var/nix/var/nix/daemon-socket 0755 root root   -
d /var/nix/var/log               0755 root root   -
d /var/nix/var/log/nix           0755 root root   -
EOF

# The nix-filesystem package's tmpfiles entries target the read-only image /nix
# and would fail on every boot. The entries above cover the same paths inside
# the bind-mount source, so mask the original with an empty override. A symlink
# to /dev/null would mask it too, but `bootc container lint` follows entries in
# /etc/tmpfiles.d and errors out on a link leaving the rootfs.
: > /etc/tmpfiles.d/nix-filesystem.conf

cat > /usr/lib/systemd/system/nix.mount << 'EOF'
[Unit]
Description=Nix Store
Documentation=https://nixos.org/manual
# A mount unit is Before=local-fs.target by default, but tmpfiles-setup (which
# creates the /var/nix source) runs After=local-fs.target. Keeping the default
# dependencies would form an ordering cycle that systemd breaks by dropping
# local-fs.target. Opt out and state the ordering explicitly instead.
DefaultDependencies=no
RequiresMountsFor=/var
After=systemd-tmpfiles-setup.service
Before=nix-daemon.socket nix-daemon.service umount.target
Conflicts=umount.target

[Mount]
What=/var/nix
Where=/nix
Type=none
Options=bind

[Install]
WantedBy=multi-user.target
EOF

# nix 2.x ships a single /usr/bin/nix binary; there is no nix-daemon executable.
# RequiresMountsFor=/nix pulls in nix.mount and orders after it, so the daemon
# never starts against the read-only image store.
cat > /usr/lib/systemd/system/nix-daemon.socket << 'EOF'
[Unit]
Description=Nix Daemon Socket
Documentation=man:nix-daemon https://nixos.org/manual
RequiresMountsFor=/nix

[Socket]
ListenStream=/nix/var/nix/daemon-socket/socket

[Install]
WantedBy=sockets.target
EOF

cat > /usr/lib/systemd/system/nix-daemon.service << 'EOF'
[Unit]
Description=Nix Daemon
Documentation=man:nix-daemon https://nixos.org/manual
RequiresMountsFor=/nix

[Service]
ExecStart=/usr/bin/nix daemon
KillMode=process
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
Also=nix-daemon.socket
EOF

# nix-command and flakes are already enabled by the packaged /etc/nix/nix.conf.

systemctl enable nix.mount
systemctl enable nix-daemon.socket

### Ink desktop (swayfx + eww)
## Default dotfiles live in /etc/skel for new users; `ink-sync` copies them into
## an existing home. Sway itself is selected from the GDM session menu.
cp -a /ctx/system_files/. /
chmod +x /usr/bin/ink-layout /usr/bin/ink-sync /usr/bin/ink-lock /usr/bin/ink-ssh-load /usr/bin/ink-gameguard \
    /etc/skel/.config/eww/scripts/*

# Fonts of the Pixel Guild look: IBM Plex Sans and Mono come from Fedora (ibm-plex-sans-fonts, ibm-plex-mono-fonts,
# installed above); Pixelify Sans is not packaged by Fedora, so its file (weight 600, from the Inkunome design system,
# SIL OFL 1.1) ships in /usr/share/fonts/ink-pixelify-sans/. Copied after dnf, it missed fontconfig's cache trigger.
fc-cache -f /usr/share/fonts/ink-pixelify-sans

# ssh-agent as a user service for every user (its socket starts it on first use, ink-ssh-load unlocks the key at login)
systemctl --global enable ssh-agent.socket

# Bazzite's GNOME base already ships gdm; keep it as the greeter (it lists the
# "Sway" session installed by swayfx) and keep GNOME as a fallback session.
systemctl enable gdm
