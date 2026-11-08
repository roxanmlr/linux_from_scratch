#!/usr/bin/env bash
# Clean $LFS 
set -euo pipefail

#source "$(dirname "$0")/env.sh"
LFS_USER=ft_linux
FT_LINUX=/mnt/ft_linux
LFS=$FT_LINUX

[ -n "$LFS" ] && [ "$LFS" != / ] || { echo "Invalid FT_LINUX env var"; exit 1; }
mountpoint -q "$FT_LINUX" || { echo "$FT_LINUX not mounted, launch host_preparation 07_mounting.sh"; exit 1;}
id "$LFS_USER" &>/dev/null || { echo "User $LFS_USER absent"; exit 1;}

echo "Actuel content of $FT_LINUX :"; ls -A "$FT_LINUX"
read -rp "Erase all except sources/, boot/ and lost+found/ ? [y/N]" r
[ "$r" = y ] || exit 1

# Remove all except listed directories
sudo find "$FT_LINUX" -mindepth 1 -maxdepth 1 \
	! -name sources ! -name boot ! -name lost+found \
	-exec rm -rf {} +

# Remove directories in sources
sudo find "$FT_LINUX/sources" -mindepth 1 -maxdepth 1 -type d -exec \
	rm -rf {} +

# Recreate minimal arborescence
sudo mkdir -pv "$FT_LINUX"/{etc,var} "$FT_LINUX"/usr/{bin,lib,sbin}
for i in bin lib sbin; do sudo ln -sv usr/$i "$FT_LINUX/$i"; done
case $(uname -m) in x86_64) sudo mkdir -pv "$FT_LINUX/lib64" ;; esac
sudo mkdir -pv "$FT_LINUX/tools"

sudo chown -v "$LFS_USER" "$FT_LINUX"/{usr{,/*},var,etc,tools}
case $(uname -m) in x86_64) sudo chown -v "$LFS_USER" "$FT_LINUX/lib64" ;; esac

echo "Ready for : su - $LFS_USER then run cross_toolchain.sh"
