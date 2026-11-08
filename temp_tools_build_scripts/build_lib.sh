# must be sourced

LFS_USER=${LFS_USER:-ft_linux}
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() { echo "ERREUR: $*" >&2; exit 1; }

ft_linux_init(){
	if [ -z "${LFS_CLEAN_ENV:-}" ]; then
		local self
		self="$(realpath "${BASH_SOURCE[1]}")"
		exec env -i HOME="$HOME" TERM="${TERM:-xterm}" \
		LFS_CLEAN_ENV=1 ${MAKEFLAGS:+MAKEFLAGS="$MAKEFLAGS"} \
		/bin/bash --noprofile --norc "$self" "$@"
	fi

	set -euo pipefail
	source "$LIB_DIR/build_env.sh"

	# Guardrails
	[ "$(id -u)" -ne 0 ] || die "don't launch build in root"
	[ "$(id -un)" = "$LFS_USER" ] || die "must be launched as $LFS_USER (su - $LFS_USER)"
	[ -n "$FT_LINUX" ] && [ "$FT_LINUX" != / ]  || die "env var FT_LINUX is invalid"
	mountpoint -q "$FT_LINUX" || dire "$FT_LINUX is not mounted"
	[ -d "$FT_LINUX/sources" ]  || dire "$FT_LINUX/sources is absent"
	[ -w "$FT_LINUX/tools" ]  || dire "$FT_LINUX/sources is absent or not accessible to $LFS_USER"
	[ -w "$FT_LINUX/usr" ]  || dire "$FT_LINUX/usr is absent or not accessible to $LFS_USER"

	export SRC="$FT_LINUX/sources"
	STAMPS="$SRC/.stamps"
	LOGS="$SRC/logs"
	mkdir -p "$STAMPS" "$LOGS"

	echo "FT_LINUX=$FT_LINUX FT_LINUX_TGT=$FT_LINUX_TGT MAKEFLAGS=$MAKEFLAGS"
}


strip_ext() {
	local b;
	b="$(basename "$1")"
	b="${b%.tar.*}"
	echo "${b%.tgz}"
}

find_tarball(){
	local f
	f="$(compgen -G "$SRC/$1-[0-9]*.tar.*" || compgen -G "$SRC/$1-[0-9]*.tgz" || true)"
	[ -n "$f" ] || die "archive of '$1' not found in $SRC"
	[ "$(wc -l <<<"$f")" -eq 1 ] || die "multiples archives found for '$1' : $f"
	echo "$f"
}

pkg_version() { local b; b="$(strip_ext "$(find_tarball "$1")")"; echo "${b#"$1"-}"; }

unpack_as() {
    local t; t="$(find_tarball "$1")"
    tar -xf "$t"
    mv -v "$(strip_ext "$t")" "$2"
}


### Replayable steps
# build <step> <package> <function>
# - étape déjà faite (tampon présent)  -> ignorée
# - sinon : source réextraite à neuf, fonction lancée dans le dossier
#   du paquet avec set -e, sortie dans $LOGS/<étape>.log
# - succès : dossier source supprimé, tampon posé
build() {
    local step=$1 pkg=$2 fn=$3
    local stamp="$STAMPS/$step" log="$LOGS/$step.log"
 
    if [ -e "$stamp" ]; then
        printf '[déjà fait] %s\n' "$step"
        return 0
    fi
 
    local tarball dir
    tarball="$(find_tarball "$pkg")"
    dir="$SRC/$(strip_ext "$tarball")"
 
    printf '[build]     %-16s %s ... ' "$step" "$(basename "$tarball")"
    rm -rf "$dir"
    tar -xf "$tarball" -C "$SRC"
    [ -d "$dir" ] || die "l'archive ne crée pas $dir"
 
    local start=$SECONDS rc=0
    bash --noprofile --norc -c "set +h; set -euo pipefail; $(declare -f); cd \"\$1\"; $fn" \
        _ "$dir" >"$log" 2>&1 || rc=$?
 
    if [ $rc -ne 0 ]; then
        echo "ÉCHEC"
        echo "----- fin de $log -----"
        tail -n 25 "$log"
        echo "-----"
        echo "Corrige le problème puis relance le script : il reprendra à '$step'."
        exit 1
    fi
 
    rm -rf "$dir"
    echo "$step $((SECONDS - start))s" >>"$LOGS/durations.txt"
    touch "$stamp"
    echo "ok ($((SECONDS - start))s)"
}
