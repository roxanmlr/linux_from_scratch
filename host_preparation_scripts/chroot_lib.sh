# Fonctions communes pour les scripts lancés DANS le chroot (en root).
# Même logique de reprise que build_lib.sh : tampons dans /sources/.stamps.

die() { echo "ERREUR: $*" >&2; exit 1; }

chroot_init() {
    set -euo pipefail
    set +h
    umask 022

    [ "$(id -u)" -eq 0 ]  || die "à lancer en root dans le chroot"
    [ -e /proc/self ]     || die "/proc non monté (21_mount_vfs.sh sur l'hôte)"
    # Garde-fou : une vraie distro a /etc/os-release, le système LFS pas encore
    [ ! -e /etc/os-release ] || die "on dirait l'hôte, pas le chroot ! (passe par 22_enter_chroot.sh)"
    [ -d /sources ]       || die "/sources absent"

    export SRC=/sources
    STAMPS="$SRC/.stamps"
    LOGS="$SRC/logs"
    mkdir -p "$STAMPS" "$LOGS"
    echo "chroot OK  PATH=$PATH  MAKEFLAGS=${MAKEFLAGS:-}"
}

strip_ext() { local b; b="$(basename "$1")"; b="${b%.tar.*}"; echo "${b%.tgz}"; }

find_tarball() {
    local f
    f="$(compgen -G "$SRC/$1-[0-9]*.tar.*" || compgen -G "$SRC/$1-[0-9]*.tgz" || true)"
    [ -n "$f" ]                  || die "archive de '$1' introuvable dans $SRC"
    [ "$(wc -l <<<"$f")" -eq 1 ] || die "plusieurs archives pour '$1' : $f"
    echo "$f"
}

pkg_version() { local b; b="$(strip_ext "$(find_tarball "$1")")"; echo "${b#"$1"-}"; }

# Exécute <fonction> dans <dossier>, dans un bash séparé (set -e toujours actif)
_run() {
    local step=$1 fn=$2 dir=$3
    local log="$LOGS/$step.log" start=$SECONDS rc=0
    bash --noprofile --norc -c "set +h; set -euo pipefail; $(declare -f); cd \"\$1\"; $fn" \
        _ "$dir" >"$log" 2>&1 || rc=$?
    if [ $rc -ne 0 ]; then
        echo "ÉCHEC"
        echo "----- fin de $log -----"
        tail -n 25 "$log"
        echo "-----"
        echo "Corrige le problème puis relance : reprise à '$step'."
        exit 1
    fi
    echo "$step $((SECONDS - start))s" >>"$LOGS/durations.txt"
    touch "$STAMPS/$step"
    echo "ok ($((SECONDS - start))s)"
}

# step <étape> <fonction> : étape sans archive (création de dossiers, fichiers...)
step() {
    local step=$1 fn=$2
    if [ -e "$STAMPS/$step" ]; then printf '[déjà fait] %s\n' "$step"; return 0; fi
    printf '[étape]     %-18s ... ' "$step"
    _run "$step" "$fn" /
}

# build <étape> <paquet> <fonction> : source réextraite à neuf, supprimée si succès
build() {
    local step=$1 pkg=$2 fn=$3
    if [ -e "$STAMPS/$step" ]; then printf '[déjà fait] %s\n' "$step"; return 0; fi
    local tarball dir
    tarball="$(find_tarball "$pkg")"
    dir="$SRC/$(strip_ext "$tarball")"
    printf '[build]     %-18s %s ... ' "$step" "$(basename "$tarball")"
    rm -rf "$dir"
    tar -xf "$tarball" -C "$SRC"
    [ -d "$dir" ] || die "l'archive ne crée pas $dir"
    _run "$step" "$fn" "$dir"
    rm -rf "$dir"
}
