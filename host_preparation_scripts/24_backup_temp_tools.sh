#!/usr/bin/env bash
# LFS 12.4 - 7.13.2 Backup (sur l'hôte, chroot quitté)
#   BACKUP=/chemin/archive.tar.xz ./24_backup_temp_tools.sh
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/env.sh"
BACKUP=${BACKUP:-$HOME/lfs-temp-tools-12.4.tar.xz}

[ -n "$LFS" ] && [ "$LFS" != / ] || { echo "LFS invalide"; exit 1; }
mountpoint -q "$LFS" || { echo "$LFS non monté"; exit 1; }
[ -e "$LFS/sources/.stamps/07.13-cleanup" ] || { echo "chapitre 7 incomplet (nettoyage 7.13.1 non fait)"; exit 1; }
for m in dev proc sys run; do
    mountpoint -q "$LFS/$m" && { echo "$LFS/$m encore monté, lance 23_umount_vfs.sh"; exit 1; }
done
case "$(realpath -m "$BACKUP")" in "$LFS"/*) echo "l'archive ne doit pas être dans $LFS"; exit 1 ;; esac

echo "Sauvegarde de $LFS vers $BACKUP ..."
( cd "$LFS" && sudo XZ_OPT=-T0 tar -cJpf "$BACKUP" . )
sudo chown "$(id -u):$(id -g)" "$BACKUP"
ls -lh "$BACKUP"
