#!/bin/bash

## To Use:
#  apt install curl
#  curl -L -O https://raw.githubusercontent.com/samirparikh/proxmox/main/install-docker-debian.sh
#  chmod +x install-docker-debian.sh
#  ./install-docker-debian.sh

set -euo pipefail

echo "=== Installing Docker on Debian ==="

echo "Updating package lists..."
apt update

echo "Upgrading packages..."
apt upgrade -y

echo "Installing prerequisites..."
apt install -y ca-certificates

echo "Setting up Docker GPG key..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo "Adding Docker repository..."
tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

echo "Updating package lists with Docker repo..."
apt update

echo "Installing Docker..."
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "=== Checking Docker status ==="
systemctl status docker --no-pager

echo "=== Testing Docker with hello-world ==="
docker run hello-world

echo "=== Docker installation complete ==="
