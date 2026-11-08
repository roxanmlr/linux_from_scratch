#!/usr/bin/env bash
# LFS 12.4 - 7.2 Changing Ownership (sur l'hôte, via sudo)
# Idempotent : --from ne touche que ce qui appartient encore à ft_linux.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/env.sh"
LFS_USER=${LFS_USER:-ft_linux}
 
[ -n "$LFS" ] && [ "$LFS" != / ] || { echo "LFS invalide"; exit 1; }
mountpoint -q "$LFS" || { echo "$LFS non monté, lance 07_mounting.sh"; exit 1; }
[ -e "$LFS/sources/.stamps/06.18-gcc-pass2" ] || { echo "chapitre 6 incomplet"; exit 1; }
 
sudo chown --from "$LFS_USER" -R root:root "$LFS"/{usr,var,etc,tools}
case $(uname -m) in
  x86_64) sudo chown --from "$LFS_USER" -R root:root "$LFS/lib64" ;;
esac
# Tampons et logs créés par ft_linux : son UID n'existera pas dans le chroot
sudo chown --from "$LFS_USER" -R root:root "$LFS/sources"
 
echo "Propriété rendue à root. Ne relance plus les scripts 10/11 en tant que $LFS_USER."
