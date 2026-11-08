# Fonctions communes pour les scripts lancés DANS le chroot (en root).
# Reprise : une étape réussie pose un tampon dans /sources/.stamps.
#
# Variables utiles :
#   TESTS=critical (défaut) : tests des paquets que LFS juge critiques
#                             (glibc, binutils, gmp, mpfr, mpc, gcc)
#   TESTS=all               : tous les tests proposés par le livre
#   TESTS=none              : aucun test
# Les tests ne bloquent pas le build : les échecs sont listés dans
# /sources/logs/tests-summary.txt, à relire (le livre en attend certains).

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
    export STAMPS="$SRC/.stamps"
    export LOGS="$SRC/logs"
    export TESTS="${TESTS:-critical}"
    mkdir -p "$STAMPS" "$LOGS"
    echo "chroot OK  MAKEFLAGS=${MAKEFLAGS:-}  TESTS=$TESTS"
}

# Étape précédente obligatoire : need_stamp 07.13-cleanup
need_stamp() { [ -e "$STAMPS/$1" ] || die "étape '$1' non faite, lance d'abord le script qui la contient"; }

strip_ext() { local b; b="$(basename "$1")"; b="${b%.tar.*}"; echo "${b%.tgz}"; }

# Fichier unique dans $SRC correspondant à un motif : find_file 'glibc-*-fhs-1.patch'
find_file() {
    local f
    f="$(compgen -G "$SRC/$1" || true)"
    [ -n "$f" ]                  || die "aucun fichier '$1' dans $SRC"
    [ "$(wc -l <<<"$f")" -eq 1 ] || die "plusieurs fichiers pour '$1' : $f"
    echo "$f"
}

# Archive d'un paquet : find_tarball gcc  ou  find_tarball 'tcl*-src.tar.gz'
find_tarball() {
    case "$1" in
        *'*'*) find_file "$1" ;;
        *)     if compgen -G "$SRC/$1-[0-9]*.tar.*" >/dev/null; then
                   find_file "$1-[0-9]*.tar.*"
               else
                   find_file "$1-[0-9]*.tgz"
               fi ;;
    esac
}

pkg_version() { local b; b="$(strip_ext "$(find_tarball "$1")")"; echo "${b#"$1"-}"; }

# Dans une étape : t <commande...> lance un test si TESTS le permet, sans bloquer
want_tests() {
    case "$TESTS" in
        all)      return 0 ;;
        none)     return 1 ;;
        critical) case "$STEP" in *-glibc|*-binutils|*-gmp|*-mpfr|*-mpc|*-gcc) return 0 ;; esac; return 1 ;;
        *)        return 1 ;;
    esac
}
t() {
    want_tests || { echo "== tests ignorés ($TESTS) : $*"; return 0; }
    echo "== TESTS : $*  (sortie dans $LOGS/$STEP-tests.log)"
    if "$@" >>"$LOGS/$STEP-tests.log" 2>&1; then
        echo "== tests OK"
    else
        echo "== TESTS EN ÉCHEC : $*"
        echo "$STEP : échec de '$*' (voir $STEP-tests.log)" >>"$LOGS/tests-summary.txt"
    fi
}

# Exécute <fonction> dans <dossier>, dans un bash séparé (set -e toujours actif)
# Variables disponibles dans l'étape : P (nom du dossier source, ex. xz-5.8.1), STEP
_run() {
    local step=$1 fn=$2 dir=$3
    local log="$LOGS/$step.log" start=$SECONDS rc=0
    STEP="$step" P="$(basename "$dir")" \
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

# step <étape> <fonction> : étape sans archive (fichiers de config, nettoyage...)
step() {
    local step=$1 fn=$2
    if [ -e "$STAMPS/$step" ]; then printf '[déjà fait] %s\n' "$step"; return 0; fi
    printf '[étape]     %-22s ... ' "$step"
    _run "$step" "$fn" /
}

# build <étape> <paquet|motif> <fonction> : source réextraite à neuf, supprimée si succès
build() {
    local step=$1 pkg=$2 fn=$3
    if [ -e "$STAMPS/$step" ]; then printf '[déjà fait] %s\n' "$step"; return 0; fi
    local tarball dir top
    tarball="$(find_tarball "$pkg")"
    printf '[build]     %-22s %s ... ' "$step" "$(basename "$tarball")"
    # Dossier créé par l'archive (lu dans l'archive, pas deviné depuis son nom)
    top="$(tar -tf "$tarball" | sed -n '1{s@^\./@@;s@/.*@@;p}')"
    [ -n "$top" ] || die "impossible de lire $tarball"
    dir="$SRC/$top"
    rm -rf "$dir"
    tar -xf "$tarball" -C "$SRC"
    [ -d "$dir" ] || die "l'archive ne crée pas $dir"
    _run "$step" "$fn" "$dir"
    rm -rf "$dir"
}
