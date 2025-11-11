#!/bin/bash

set -ouex pipefail

### Install packages

dnf5 install -y @cosmic-desktop-environment

# Switch to cosmic greeter
systemctl disable display-manager 
systemctl enable cosmic-greeter.service -f

