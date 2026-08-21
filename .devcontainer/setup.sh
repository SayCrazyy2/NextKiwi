#!/bin/bash
set -ex

echo "=== NextKiwi Build Environment Setup ==="

# Install build dependencies
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  openjdk-17-jdk-headless ninja-build ccache pkg-config git-lfs \
  curl ca-certificates python3 dh-python lsb-release tzdata \
  build-essential gperf libncurses5 libncurses5-dev

# Create swap file (32GB) to prevent OOM during linking
if [ ! -f /swapfile ]; then
  echo "Creating 32GB swap file..."
  fallocate -l 32G /swapfile || dd if=/dev/zero of=/swapfile bs=1G count=32
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# Clone depot_tools if not present
if [ ! -d /workspaces/depot_tools ]; then
  echo "Cloning depot_tools..."
  git clone --depth=1 https://chromium.googlesource.com/chromium/tools/depot_tools.git /workspaces/depot_tools
fi

# Fix depot_tools python3 bootstrap
echo -n "python3/bin" > /workspaces/depot_tools/python3_bin_reldir.txt 2>/dev/null || true
mkdir -p /workspaces/depot_tools/python3/bin
ln -sf /usr/bin/python3 /workspaces/depot_tools/python3/bin/python3

# Configure ccache
ccache --max-size 50G || true

# Set up PATH
echo 'export PATH="$PATH:/workspaces/depot_tools"' >> /root/.bashrc
echo 'export GCLIENT_SUPPRESS_GIT_VERSION_WARNING=1' >> /root/.bashrc

echo ""
echo "=== Setup complete! ==="
echo "To build NextKiwi, run: bash scripts/codespace_build.sh"
echo "Or for incremental builds: bash scripts/codespace_build.sh --incremental"