#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
need_loop

sudo mkdir -pv $FT_LINUX
mountpoint -q "$FT_LINUX" || sudo mount -v -t ext4 "${LOOP}p4" "$FT_LINUX"
sudo mkdir -pv $FT_LINUX/boot
mountpoint -q "$FT_LINUX/boot" || sudo mount -v -t ext4 "${LOOP}p2" "$FT_LINUX/boot"

sudo chown root:root $FT_LINUX
sudo chmod 755 $FT_LINUX
swapon --show=NAME --noheadings | grep -qx "${LOOP}p3" || sudo swapon -v "${LOOP}p3"
