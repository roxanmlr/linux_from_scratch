#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root"
	exit 1
fi

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/env.sh"

groupadd ft_linux
useradd -s /bin/bash -g ft_linux -m -k /dev/null ft_linux

passwd ft_linux

chown -v ft_linux $FT_LINUX/{usr{,/*},var,etc,tools}
case $(uname -m) in
	x86_64) chown -v ft_linux $FT_LINUX/lib64 ;;
esac

su - ft_linux

echo "You have successfully created ft_linux user"
