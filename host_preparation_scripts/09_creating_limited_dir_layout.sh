#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root"
	exit 1
fi

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/env.sh"

mkdir -pv $FT_LINUX/{etc,var} $FT_LINUX/usr/{bin,lib,sbin}

for i in bin lib sbin; do
	ln -sv usr/$i $FT_LINUX/$i
done

case $(uname -m) in
	x86_64) mkdir -pv $FT_LINUX/lib64 ;;
esac

mkdir -pv $FT_LINUX/tools
