#!/bin/bash
# Installe les sources du noyau dans /usr/src/kernel-<version> (exigence ft_linux).
# Le chapitre 10 compile le noyau puis supprime son dossier source, comme pour
# tous les paquets : ce script le réinstalle à l'emplacement demandé par le sujet.
#
# Utilisable dans le chroot (./22_enter_chroot.sh 52_kernel_sources.sh)
# ou directement dans la VM, en root (/sources est sur la partition racine) :
#   bash /sources/ft_scripts/52_kernel_sources.sh
set -euo pipefail

SRC=/sources
[ "$(id -u)" -eq 0 ] || { echo "à lancer en root"; exit 1; }

tarball=$(ls "$SRC"/linux-[0-9]*.tar.xz 2>/dev/null || true)
[ -n "$tarball" ] && [ "$(echo "$tarball" | wc -l)" -eq 1 ] \
    || { echo "archive linux-*.tar.xz introuvable (ou plusieurs) dans $SRC"; exit 1; }

top=$(basename "$tarball" .tar.xz)          # linux-6.16.1
ver=${top#linux-}                           # 6.16.1
dest=/usr/src/kernel-$ver

release=$(cat /boot/.ft_kernel_release 2>/dev/null || true)   # 6.16.1-lmilando
if [ -z "$release" ]; then
    k=(/boot/vmlinuz-*)
    [ -e "${k[0]}" ] || { echo "aucun /boot/vmlinuz-* : /boot est-il monté ?"; exit 1; }
    release=${k[0]#/boot/vmlinuz-}
fi

if [ -f "$dest/Makefile" ]; then
    echo "$dest existe déjà."
else
    echo "Extraction de $(basename "$tarball") dans /usr/src ..."
    rm -rf "/usr/src/$top"
    tar -xf "$tarball" -C /usr/src
    mv -v "/usr/src/$top" "$dest"
fi

# Configuration du noyau installé, pour pouvoir recompiler ou construire des modules
if [ -f "/boot/config-$release" ]; then
    cp -v "/boot/config-$release" "$dest/.config"
fi
chown -R root:root "$dest"

# Liens standards vers les sources du noyau
if [ -d "/lib/modules/$release" ]; then
    ln -sfnv "$dest" "/lib/modules/$release/build"
    ln -sfnv "$dest" "/lib/modules/$release/source"
fi

echo
echo "Sources du noyau : $dest"
grep -E '^(VERSION|PATCHLEVEL|SUBLEVEL) =' "$dest/Makefile"
du -sh "$dest"
