#!/usr/bin/env bash
# Démonte les systèmes de fichiers virtuels du chroot (début de 7.13.2). Idempotent.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/env.sh"
 
[ -n "$LFS" ] && [ "$LFS" != / ] || { echo "LFS invalide"; exit 1; }
 
for m in dev/shm dev/pts sys proc run dev; do
    if mountpoint -q "$LFS/$m"; then sudo umount -v "$LFS/$m"; fi
done
 
findmnt -R "$LFS" || true
