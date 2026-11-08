#!/usr/bin/env bash
# LFS 12.4 - 7.13.3 Restore (sur l'hôte) : remet $LFS dans l'état de la sauvegarde
#   BACKUP=/chemin/archive.tar.xz ./25_restore_temp_tools.sh
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/env.sh"
BACKUP=${BACKUP:-$HOME/lfs-temp-tools-12.4.tar.xz}

[ -n "$LFS" ] && [ "$LFS" != / ] || { echo "LFS invalide"; exit 1; }
mountpoint -q "$LFS" || { echo "$LFS non monté"; exit 1; }
[ -s "$BACKUP" ] || { echo "archive $BACKUP introuvable"; exit 1; }
for m in dev proc sys run; do
    mountpoint -q "$LFS/$m" && { echo "$LFS/$m encore monté, lance 23_umount_vfs.sh"; exit 1; }
done

read -rp "Effacer tout $LFS (sauf boot/ et lost+found/) et restaurer $BACKUP ? [y/N] " r
[ "$r" = y ] || exit 1

# boot/ est un point de montage : on ne le supprime pas, tar réécrit son contenu
sudo find "$LFS" -mindepth 1 -maxdepth 1 ! -name boot ! -name lost+found -exec rm -rf {} +
sudo find "$LFS/boot" -mindepth 1 -maxdepth 1 ! -name lost+found -exec rm -rf {} +
( cd "$LFS" && sudo tar -xpf "$BACKUP" )
echo "Restauré. Relance 21_mount_vfs.sh avant de rentrer dans le chroot."
