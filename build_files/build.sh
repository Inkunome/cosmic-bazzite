#!/bin/bash

set -ouex pipefail

### Install packages

dnf5 install -y @cosmic-desktop-environment
dnf5 remove -y "libreoffice-*"

# Clear cache
dnf5 clean all 
rm -rf /var/cache/dnf/*

# Switch to cosmic greeter
# systemctl disable display-manager 
# systemctl enable cosmic-greeter.service -f

