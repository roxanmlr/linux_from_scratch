#!/usr/bin/env bash
set -euo pipefail

if [ ! -e .loopdev ]; then echo "First attached the loop device"; exit 1; fi
LOOP=$(cat .loopdev)


sudo parted $LOOP --script mklabel gpt

sudo parted $LOOP --script mkpart bios_grub 1MiB 3MiB
sudo parted $LOOP --script set 1 bios_grub on

sudo parted $LOOP --script mkpart boot ext4 3MiB 1027MiB

sudo parted $LOOP --script mkpart swap linux-swap 1027MiB 5123MiB
sudo parted $LOOP --script mkpart root ext4 5123MiB 100%
