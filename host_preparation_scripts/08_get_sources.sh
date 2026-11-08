#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/env.sh"

LFS_VERSION="12.4"
BOOK_URL="https://www.linuxfromscratch.org/lfs/view/$LFS_VERSION"
MIRROR="https://ftp.osuosl.org/pub/lfs/lfs-packages/$LFS_VERSION"
SRC="$FT_LINUX/sources"

mountpoint -q "$FT_LINUX" || { echo "$FT_LINUX not mounted, launch script 07"; exit 1;}

sudo mkdir -pv "$SRC"
sudo chmod -v a+wt "$SRC"

wget -q -O "$DIR/wget-list-sysv.orig" "$BOOK_URL/wget-list-sysv"
wget -q -O "$SRC/md5sums"             "$BOOK_URL/md5sums"

wget --input-file="$DIR/wget-list-sysv" --continue --tries=3 \
     --directory-prefix="$SRC" || true

while read -r _ f; do
    [ -s "$SRC/$f" ] && continue
    echo ">> $f missing, trying the lfs mirror"
    wget --continue --tries=3 -P "$SRC" "$MIRROR/$f" || echo "!! $f introuvable"
done < "$SRC/md5sums"

( cd "$SRC" && md5sum -c --quiet md5sums ) && echo "All sources are OK"

sudo chown root:root $FT_LINUX/sources/*
