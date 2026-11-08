#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
need_loop

if sudo blkid "${LOOP}p4" &> /dev/null; then
	read -rp "Partitions déjà formatées. Tout effacer ? [y/N] " r
	[ "$r" = y ] || exit 1
fi

sudo mkfs.ext4 -F -L FT_LINUX_BOOT "${LOOP}p2"
sudo mkswap -L FT_LINUX_SWAP "${LOOP}p3"
sudo mkfs.ext4 -F -L FT_LINUX_ROOT "${LOOP}p4"
