#!/bin/bash
# Vérifie, DANS LA VM démarrée, les exigences du sujet ft_linux.
#   En root :  bash /sources/ft_scripts/80_check_ft_linux.sh
#   Options :  LOGIN=lmilando (défaut)   VERBOSE=1 (affiche les versions)
# Code de sortie : 0 si tout est OK, 1 sinon.
# Pas de set -e / pipefail : chaque test gère son propre échec.

LOGIN="${LOGIN:-lmilando}"
VERBOSE="${VERBOSE:-0}"
PATH=/usr/bin:/usr/sbin:/bin:/sbin

if [ -t 1 ]; then G=$'\e[32m'; R=$'\e[31m'; Y=$'\e[33m'; B=$'\e[1m'; N=$'\e[0m'; else G= R= Y= B= N=; fi
pass=0; fail=0; FAILED=()

ok()    { printf '  %s[ OK ]%s %s\n' "$G" "$N" "$1"; pass=$((pass+1)); }
ko()    { printf '  %s[FAIL]%s %s\n' "$R" "$N" "$1"; fail=$((fail+1)); FAILED+=("$1"); }
info()  { printf '         %s%s%s\n' "$Y" "$1" "$N"; }
title() { printf '\n%s== %s ==%s\n' "$B" "$1" "$N"; }

# Résultat d'une liste de conditions : check "<nom>" <test> [<test>...]
check() {
    local name=$1; shift
    local t miss=()
    for t in "$@"; do eval "$t" >/dev/null 2>&1 || miss+=("$t"); done
    if [ ${#miss[@]} -eq 0 ]; then ok "$name"; else ko "$name"; for t in "${miss[@]}"; do info "manque : $t"; done; fi
}

cmd()  { command -v "$1"; }                               # programme dans le PATH
lib()  { compgen -G "/usr/lib/$1.so*" || compgen -G "/usr/lib64/$1.so*"; }   # bibliothèque partagée
file_() { [ -e "$1" ]; }                                  # fichier ou dossier
hdr()  { [ -e "/usr/include/$1" ]; }                      # en-tête C

ver() {   # première ligne de version, en mode VERBOSE
    [ "$VERBOSE" = 1 ] || return 0
    local v; v=$("$@" 2>&1 | head -n1); info "$v"
}

[ "$(id -u)" -eq 0 ] || echo "${Y}Conseil : lance ce script en root (certains tests lisent /dev et /boot).${N}"

# ---------------------------------------------------------------------------
title "Paquets requis"

check "Acl"            'cmd getfacl'    'cmd setfacl'  'lib libacl'                 ; ver getfacl --version
check "Attr"           'cmd getfattr'   'cmd setfattr' 'lib libattr'                ; ver getfattr --version
check "Autoconf"       'cmd autoconf'   'cmd autoreconf'                            ; ver autoconf --version
check "Automake"       'cmd automake'   'cmd aclocal'                               ; ver automake --version
check "Bash"           'cmd bash'       '[ "$(readlink -f /bin/sh)" = /usr/bin/bash ]' ; ver bash --version
check "Bc"             'cmd bc'         'cmd dc'                                    ; ver bc --version
check "Binutils"       'cmd ld'         'cmd as'       'cmd objdump' 'lib libbfd'   ; ver ld --version
check "Bison"          'cmd bison'      'cmd yacc'                                  ; ver bison --version
check "Bzip2"          'cmd bzip2'      'lib libbz2'                                ; ver bzip2 --help
check "Check"          'lib libcheck'   'hdr check.h'  'file_ /usr/lib/pkgconfig/check.pc'
check "Coreutils"      'cmd ls'         'cmd cp'       'cmd stat'                   ; ver ls --version
check "DejaGNU"        'cmd runtest'                                                ; ver runtest --version
check "Diffutils"      'cmd diff'       'cmd cmp'                                   ; ver diff --version
check "Eudev (udev)"   'cmd udevadm'    'file_ /usr/lib/libudev.so.1' 'file_ /etc/udev/udev.conf' ; ver udevadm --version
info  "LFS 12.4 fournit udev issu de systemd à la place d'Eudev (même rôle, même API libudev)"
check "E2fsprogs"      'cmd mke2fs'     'cmd e2fsck'   'cmd tune2fs'                ; ver mke2fs -V
check "Expat"          'lib libexpat'   'hdr expat.h'
check "Expect"         'cmd expect'     'compgen -G "/usr/lib/libexpect*.so"'       ; ver expect -v
check "File"           'cmd file'       'lib libmagic'                              ; ver file --version
check "Findutils"      'cmd find'       'cmd xargs'                                 ; ver find --version
check "Flex"           'cmd flex'       'cmd lex'                                   ; ver flex --version
check "Gawk"           'cmd gawk'       '[ "$(readlink -f "$(command -v awk)")" = "$(readlink -f "$(command -v gawk)")" ]' ; ver gawk --version
check "GCC"            'cmd gcc'        'cmd g++'      'cmd cc'     'lib libstdc++' ; ver gcc --version
check "GDBM"           'lib libgdbm'    'cmd gdbmtool'                              ; ver gdbmtool --version
check "Gettext"        'cmd gettext'    'cmd msgfmt'   'cmd xgettext'               ; ver gettext --version
check "Glibc"          'file_ /usr/lib/libc.so.6' 'cmd ldd' 'file_ /usr/lib/ld-linux-x86-64.so.2' ; ver ldd --version
check "GMP"            'lib libgmp'     'hdr gmp.h'
check "Gperf"          'cmd gperf'                                                  ; ver gperf --version
check "Grep"           'cmd grep'                                                   ; ver grep --version
check "Groff"          'cmd groff'      'cmd nroff'                                 ; ver groff --version
check "GRUB"           'cmd grub-install' 'file_ /boot/grub/grub.cfg' 'file_ /usr/lib/grub/i386-pc' ; ver grub-install --version
check "Gzip"           'cmd gzip'       'cmd gunzip'                                ; ver gzip --version
check "Iana-Etc"       'file_ /etc/services' 'file_ /etc/protocols'
check "Inetutils"      'cmd ping'       'cmd hostname' 'cmd ftp'    'cmd telnet'    ; ver ping -V
check "Intltool"       'cmd intltoolize' 'cmd intltool-update'                      ; ver intltoolize --version
check "IPRoute2"       'cmd ip'         'cmd ss'                                    ; ver ip -V
check "Kbd"            'cmd loadkeys'   'cmd setfont'  'file_ /usr/share/keymaps'   ; ver loadkeys --version
check "Kmod"           'cmd kmod'       'cmd modprobe' 'cmd lsmod'  'lib libkmod'   ; ver kmod --version
check "Less"           'cmd less'                                                   ; ver less --version
check "Libcap"         'lib libcap'     'cmd getcap'   'cmd setcap'
check "Libpipeline"    'lib libpipeline'
check "Libtool"        'cmd libtool'    'cmd libtoolize' 'lib libltdl'              ; ver libtool --version
check "M4"             'cmd m4'                                                     ; ver m4 --version
check "Make"           'cmd make'                                                   ; ver make --version
check "Man-DB"         'cmd man'        'cmd mandb'                                 ; ver man --version
check "Man-pages"      'compgen -G "/usr/share/man/man2/open.2*"' 'compgen -G "/usr/share/man/man3/printf.3*"'
check "MPC"            'lib libmpc'     'hdr mpc.h'
check "MPFR"           'lib libmpfr'    'hdr mpfr.h'
check "Ncurses"        'lib libncursesw' 'cmd tic'     'cmd clear'                  ; ver tic -V
check "Patch"          'cmd patch'                                                  ; ver patch --version
check "Perl"           'cmd perl'       'perl -e 1'                                 ; ver perl -e 'print "perl $^V\n"'
check "Pkg-config"     'cmd pkg-config' 'pkg-config --exists zlib'                  ; ver pkg-config --version
check "Procps"         'cmd ps'         'cmd top'      'cmd free'   'lib libproc2'  ; ver ps --version
check "Readline"       'lib libreadline' 'hdr readline/readline.h'
check "Psmisc"         'cmd killall'    'cmd pstree'   'cmd fuser'                  ; ver killall --version
check "Sed"            'cmd sed'                                                    ; ver sed --version
check "Shadow"         'cmd passwd'     'cmd useradd'  'file_ /etc/shadow' 'file_ /etc/login.defs'
check "Sysklogd"       'cmd syslogd'    'file_ /etc/syslog.conf'                    ; ver syslogd -v
check "Sysvinit"       'file_ /sbin/init' 'cmd shutdown' 'cmd runlevel' 'file_ /etc/inittab'
check "Tar"            'cmd tar'                                                    ; ver tar --version
check "Tcl"            'cmd tclsh'      'compgen -G "/usr/lib/libtcl8*.so"'
check "Texinfo"        'cmd makeinfo'   'cmd install-info'                          ; ver makeinfo --version
check "Time Zone Data" 'file_ /usr/share/zoneinfo/Europe/Paris' 'file_ /usr/share/zoneinfo/UTC' '[ -L /etc/localtime ]'
[ "$VERBOSE" = 1 ] && info "fuseau : $(readlink /etc/localtime)"
# Makefile.lfs peut placer ses règles dans /etc/udev/rules.d ou /usr/lib/udev/rules.d
check "Udev-lfs Tarball" 'compgen -G "/etc/udev/rules.d/55-lfs.rules" || compgen -G "/usr/lib/udev/rules.d/55-lfs.rules"' \
                         'file_ /usr/lib/udev/init-net-rules.sh'
[ "$VERBOSE" = 1 ] && info "règles udev-lfs : $(ls /etc/udev/rules.d/55-lfs.rules /usr/lib/udev/rules.d/55-lfs.rules 2>/dev/null | tr '\n' ' ')"
check "Util-linux"     'cmd mount'      'cmd lsblk'    'cmd agetty' 'cmd fdisk'     ; ver lsblk --version
check "Vim"            'cmd vim'        'cmd vi'                                    ; ver vim --version
check "XML::Parser"    'perl -MXML::Parser -e 1'
check "Xz Utils"       'cmd xz'         'lib liblzma'                               ; ver xz --version
check "Zlib"           'lib libz'       'hdr zlib.h'

# ---------------------------------------------------------------------------
title "Noyau"

REL=$(uname -r)                         # 6.16.1-lmilando
KVER=${REL%-"$LOGIN"}                   # 6.16.1
info "noyau en cours d'exécution : $REL"

check "Version du noyau suffixée par le login ($LOGIN)" '[ "$REL" != "$KVER" ]'
check "Binaire /boot/vmlinuz-<version>-$LOGIN" \
      'file_ "/boot/vmlinuz-$KVER-$LOGIN"' \
      'ls /boot/vmlinuz-* | grep -Ex "/boot/vmlinuz-[0-9]+\.[0-9]+(\.[0-9]+)?-$LOGIN"'
info "binaires présents : $(ls /boot/vmlinuz-* 2>/dev/null | tr '\n' ' ')"

KSRC=""
for d in "/usr/src/kernel-$KVER" "/usr/src/kernel-$REL"; do
    [ -f "$d/Makefile" ] && { KSRC=$d; break; }
done
if [ -n "$KSRC" ]; then
    mk=$(awk -F' = ' '/^VERSION =/{v=$2} /^PATCHLEVEL =/{p=$2} /^SUBLEVEL =/{s=$2} END{print v"."p"."s}' "$KSRC/Makefile")
    if [ "$mk" = "$KVER" ] || [ "$mk.0" = "$KVER" ] || [ "${mk%.0}" = "$KVER" ]; then
        ok "Sources du noyau dans $KSRC (Makefile : $mk)"
    else
        ko "Sources du noyau dans $KSRC, mais version $mk au lieu de $KVER"
    fi
else
    ko "Sources du noyau dans /usr/src/kernel-$KVER"
    info "absentes : lance  bash /sources/ft_scripts/52_kernel_sources.sh"
fi

# ---------------------------------------------------------------------------
title "Partitions"

ROOT_DEV=$(findmnt -no SOURCE /)
BOOT_DEV=$(findmnt -no SOURCE /boot)
SWAP_DEV=$(awk 'NR>1 && $2=="partition"{print $1; exit}' /proc/swaps)
info "/ : ${ROOT_DEV:-?}   /boot : ${BOOT_DEV:-?}   swap : ${SWAP_DEV:-?}"

check "Partition racine montée sur /"      '[ -n "$ROOT_DEV" ]' '[ -b "$ROOT_DEV" ]'
check "Partition /boot séparée"            '[ -n "$BOOT_DEV" ]' '[ -b "$BOOT_DEV" ]' '[ "$BOOT_DEV" != "$ROOT_DEV" ]'
check "Partition de swap active"           '[ -n "$SWAP_DEV" ]' '[ -b "$SWAP_DEV" ]'
check "Trois partitions distinctes"        '[ "$(printf "%s\n" "$ROOT_DEV" "$BOOT_DEV" "$SWAP_DEV" | sort -u | grep -c /dev/)" -eq 3 ]'
[ "$VERBOSE" = 1 ] && lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS | sed 's/^/         /'

# ---------------------------------------------------------------------------
title "Nom d'hôte"

HN=$(hostname)
check "Hostname = $LOGIN (actuel : $HN)" '[ "$HN" = "$LOGIN" ]' '[ "$(cat /etc/hostname)" = "$LOGIN" ]'

# ---------------------------------------------------------------------------
title "Système d'init (gestion centrale des services)"

INIT=$(readlink -f /proc/1/exe 2>/dev/null)
info "PID 1 : ${INIT:-?} ($(cat /proc/1/comm 2>/dev/null))"
check "SysVinit est le PID 1"              '[ "$(cat /proc/1/comm)" = init ]' 'file_ /etc/inittab' '! cmd systemctl'
check "Niveau d'exécution actif"           'runlevel | grep -E "[0-6S]$"'
check "Scripts de démarrage SysV"          'file_ /etc/rc.d/init.d/rc' 'compgen -G "/etc/rc.d/rc3.d/S*"'
[ "$VERBOSE" = 1 ] && info "runlevel : $(runlevel)  services rc3 : $(ls /etc/rc.d/rc3.d | tr '\n' ' ')"

# ---------------------------------------------------------------------------
title "Chargeur de démarrage"

DISK=""
[ -n "$BOOT_DEV" ] && DISK=/dev/$(lsblk -no PKNAME "$BOOT_DEV" 2>/dev/null | head -n1)
info "disque de démarrage : ${DISK:-?}"
check "GRUB installé et configuré"         'cmd grub-install' 'file_ /boot/grub/grub.cfg' 'file_ /boot/grub/i386-pc/core.img'
if [ "$(id -u)" -eq 0 ]; then
    check "GRUB présent dans le secteur d'amorçage de $DISK" \
          '[ -b "$DISK" ]' 'dd if="$DISK" bs=512 count=1 2>/dev/null | grep -a GRUB'
else
    ko "GRUB dans le secteur d'amorçage : test impossible sans root (lecture de $DISK)"
    info "relance le script en root : su -c 'bash $0'"
fi
check "Entrée GRUB pointant vers vmlinuz-$REL" 'grep "linux.*/vmlinuz-$REL" /boot/grub/grub.cfg'

# ---------------------------------------------------------------------------
title "Chargeur de modules (udev)"

check "udev en cours d'exécution"          'pgrep -x udevd || pgrep -f systemd-udevd'
check "Bootscript udev au démarrage"       'compgen -G "/etc/rc.d/rcS.d/S*udev"'
check "modprobe utilisé par le noyau"      '[ "$(cat /proc/sys/kernel/modprobe)" = /sbin/modprobe ] || [ "$(cat /proc/sys/kernel/modprobe)" = /usr/sbin/modprobe ]' 'cmd modprobe'
check "Base des modules du noyau"          'file_ "/lib/modules/$REL/modules.dep"'
check "Événements udev traités"            'udevadm info --export-db | grep -m1 "^P:"'
[ "$VERBOSE" = 1 ] && info "modules chargés : $(lsmod | tail -n +2 | wc -l) (pilotes principaux compilés en dur)"

# ---------------------------------------------------------------------------
printf '\n%s== Résultat : %d OK, %d échec(s) ==%s\n' "$B" "$pass" "$fail" "$N"
if [ $fail -gt 0 ]; then
    for f in "${FAILED[@]}"; do printf '  %s- %s%s\n' "$R" "$f" "$N"; done
    exit 1
fi
exit 0
