# Must be sourced in a clean env (env -i)

set +h
umask 022

FT_LINUX=/mnt/ft_linux
LFS=$FT_LINUX
LC_ALL=POSIX
FT_LINUX_TGT=$(uname -m)-ftlinux-linux-gnu
LFS_TGT=$FT_LINUX_TGT
PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:$PATH;fi
PATH=$FT_LINUX/tools/bin:$PATH
CONFIG_SITE=$LFS/usr/share/config.site
MAKEFLAGS=${MAKEFLAGS:--j32}

export LFS FT_LINUX FT_LINUX_TGT LFS_TGT PATH CONFIG_SITE MAKEFLAGS
