#!/usr/bin/env bash
# LFS 12.4 - 7.3 Preparing Virtual Kernel File Systems (sur l'hôte, via sudo)
# À relancer à chaque session (après reboot ou 23_umount_vfs.sh). Idempotent.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/env.sh"

[ -n "$LFS" ] && [ "$LFS" != / ] || { echo "LFS invalide"; exit 1; }
mountpoint -q "$LFS" || { echo "$LFS non monté, lance 07_mounting.sh"; exit 1; }

mnt() {  # mnt <point> <args mount...>
    local p="$LFS/$1"; shift
    if mountpoint -q "$p"; then echo "déjà monté : $p"; else sudo mount -v "$@" "$p"; fi
}

sudo mkdir -pv "$LFS"/{dev,proc,sys,run}

mnt dev     --bind /dev
mnt dev/pts -t devpts devpts -o gid=5,mode=0620
mnt proc    -t proc   proc
mnt sys     -t sysfs  sysfs
mnt run     -t tmpfs  tmpfs

if [ -h "$LFS/dev/shm" ]; then
    sudo install -v -d -m 1777 "$LFS$(realpath /dev/shm)"
else
    mnt dev/shm -t tmpfs -o nosuid,nodev tmpfs
fi

findmnt -R "$LFS"
