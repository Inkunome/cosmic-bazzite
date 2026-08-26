#!/bin/bash

set -ouex pipefail

COPRS=(
    varlad/zellij
    ryanabx/cosmic-epoch
    leloubil/wl-clip-persist
)

### Install packages

for copr in "${COPRS[@]}"; do
    dnf5 -y copr enable "$copr"
done

dnf5 install -y --setopt=install_weak_deps=False \
    alacritty \
    fira-code-fonts \
    zellij \
    cosmic-desktop \
    wl-clip-persist \
    grim \
    nix

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

# Switch to cosmic greeter
systemctl disable gdm
systemctl enable cosmic-greeter
