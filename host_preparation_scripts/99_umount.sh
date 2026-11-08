#!/usr/bin/env bash
set -euo pipefail

source env.sh

sudo swapoff "${LOOP}p3" 2>/dev/null || true
if mountpoint -q "$FT_LINUX"; then sudo umount -Rv "$FT_LINUX"; fi
sudo losetup -d "$LOOP"
rm -f "$(dirname "$0")/.loopdev"
echo "Détaché : $LOOP"
