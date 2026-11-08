#!/usr/bin/env bash
# LFS 12.4 - 7.4 Entering the Chroot Environment (sur l'hôte, via sudo)
#   ./22_enter_chroot.sh                       -> shell interactif dans le chroot
#   ./22_enter_chroot.sh 30_chroot_tools.sh    -> lance ce script dans le chroot
# Copie d'abord le dossier chroot/ vers $LFS/sources/ft_scripts (vu comme /sources/ft_scripts).
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/env.sh"

[ -n "$LFS" ] && [ "$LFS" != / ] || { echo "LFS invalide"; exit 1; }
for m in dev dev/pts proc sys run; do
    mountpoint -q "$LFS/$m" || { echo "$LFS/$m non monté, lance 21_mount_vfs.sh"; exit 1; }
done
[ "$(stat -c %U "$LFS/usr")" = root ] || { echo "$LFS/usr pas à root, lance 20_chown_root.sh"; exit 1; }

sudo mkdir -p "$LFS/sources/ft_scripts"
sudo cp "$DIR"/chroot_lib.sh "$DIR"/30_chroot_tools.sh "$LFS/sources/ft_scripts"
sudo chmod 755 "$LFS"/sources/ft_scripts/*.sh

if [ $# -gt 0 ]; then
    CMD=(/bin/bash "/sources/ft_scripts/$1")
else
    CMD=(/bin/bash --login)
fi

exec sudo chroot "$LFS" /usr/bin/env -i \
    HOME=/root                      \
    TERM="${TERM:-xterm}"           \
    PS1='(lfs chroot) \u:\w\$ '     \
    PATH=/usr/bin:/usr/sbin         \
    MAKEFLAGS="-j$(nproc)"          \
    TESTSUITEFLAGS="-j$(nproc)"     \
    "${CMD[@]}"
