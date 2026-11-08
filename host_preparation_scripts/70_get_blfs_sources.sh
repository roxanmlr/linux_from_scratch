#!/usr/bin/env bash
# Télécharge les sources d'un lot BLFS dans $LFS/sources et vérifie les MD5.
#   ./70_get_blfs_sources.sh blfs/10_net.list
# Format de la liste : « <md5>  <url> » par ligne (« - » = pas de MD5 publiée).
# Copie aussi le resolv.conf de l'hôte dans sources/ : les scripts du chroot
# s'en servent pour les rares étapes qui téléchargent (make-ca -g).
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/env.sh"

LIST="${1:?usage: $0 blfs/<lot>.list}"
[ -f "$LIST" ] || LIST="$DIR/$LIST"
[ -f "$LIST" ] || { echo "liste introuvable : $1"; exit 1; }
mountpoint -q "$LFS" || { echo "$LFS non monté, lance 07_mounting.sh"; exit 1; }
SRC="$LFS/sources"

fail=0
while read -r md5 url; do
    case "$md5" in ''|\#*) continue ;; esac
    f="$SRC/$(basename "$url")"
    if [ ! -s "$f" ]; then
        echo ">> $(basename "$url")"
        sudo wget -q --show-progress --tries=3 -O "$f.part" "$url" && sudo mv "$f.part" "$f" \
            || { echo "!! échec : $url"; sudo rm -f "$f.part"; fail=1; continue; }
    fi
    if [ "$md5" != - ]; then
        if [ "$(md5sum < "$f" | cut -d' ' -f1)" = "$md5" ]; then
            echo "OK    $(basename "$f")"
        else
            echo "MD5 FAUX  $(basename "$f") (fichier supprimé, relance le script)"
            sudo rm -f "$f"; fail=1
        fi
    else
        echo "OK    $(basename "$f") (pas de MD5 publiée)"
    fi
done < "$LIST"

sudo cp -L /etc/resolv.conf "$SRC/host-resolv.conf"

[ $fail -eq 0 ] && echo "Toutes les sources du lot sont présentes." || { echo "Des téléchargements ont échoué."; exit 1; }
