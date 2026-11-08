#!/bin/bash
# LFS 12.4 - Chapitre 8, lot 4 : 8.58 Kmod -> 8.85 Cleaning Up (DANS le chroot)
#   + Check-0.15.2 (retiré de LFS 12.4, recette de LFS 12.3, placé après Coreutils)
#   Sur l'hôte :  ./22_enter_chroot.sh 43_ch8_lot4.sh
#   Options    :  TESTS=critical|all|none  GROFF_PAGE=A4|letter  SKIP_STRIP=1
#                 LFS_VENDOR=ftlinux (vendeur de ton LFS_TGT, pour le nettoyage 8.85)
source "$(dirname "$0")/chroot_lib.sh"
chroot_init
need_stamp 08.57-meson

export GROFF_PAGE="${GROFF_PAGE:-A4}"
export SKIP_STRIP="${SKIP_STRIP:-0}"
export LFS_VENDOR="${LFS_VENDOR:-ftlinux}"
[ "$LFS_VENDOR" != pc ] || die "LFS_VENDOR=pc supprimerait le vrai GCC au nettoyage"

# Check-0.15.2 n'est pas dans le wget-list de LFS 12.4
compgen -G "$SRC/check-[0-9]*.tar.*" >/dev/null || die "check-0.15.2.tar.gz absent de /sources.
Télécharge-le sur l'hôte dans \$LFS/sources :
  https://github.com/libcheck/check/releases/download/0.15.2/check-0.15.2.tar.gz"

# 8.58 Kmod (pas de tests dans LFS)
kmod_pkg() {
    mkdir -p build
    cd       build
    meson setup --prefix=/usr ..    \
                --buildtype=release \
                -D manpages=false
    ninja
    ninja install
}

# 8.59 Coreutils
coreutils_pkg() {
    patch -Np1 -i "$(find_file 'coreutils-*-upstream_fix-1.patch')"
    patch -Np1 -i "$(find_file 'coreutils-*-i18n-1.patch')"
    autoreconf -fv
    automake -af
    FORCE_UNSAFE_CONFIGURE=1 ./configure \
                --prefix=/usr            \
                --enable-no-install-program=kill,uptime
    make

    coreutils_tests() {
        make NON_ROOT_USERNAME=tester check-root || true
        groupdel dummy 2>/dev/null || true
        groupadd -g 102 dummy -U tester
        chown -R tester .
        su tester -c "PATH=$PATH make -k RUN_EXPENSIVE_TESTS=yes check" < /dev/null
        local rc=$?
        groupdel dummy
        return $rc
    }
    t coreutils_tests

    make install
    mv -v /usr/bin/chroot /usr/sbin
    mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
    sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8
}

# Check-0.15.2 (LFS 12.3, 8.59)
check_pkg() {
    ./configure --prefix=/usr --disable-static
    make
    t make check
    make docdir=/usr/share/doc/$P install
}

# 8.60 Diffutils
diffutils_pkg() {
    ./configure --prefix=/usr
    make
    t make check
    make install
}

# 8.61 Gawk
gawk_pkg() {
    sed -i 's/extras//' Makefile.in
    ./configure --prefix=/usr
    make
    gawk_tests() { chown -R tester . && su tester -c "PATH=$PATH make check"; }
    t gawk_tests
    rm -f /usr/bin/$P
    make install
    ln -sfv gawk.1 /usr/share/man/man1/awk.1
    install -vDm644 doc/{awkforai.txt,*.{eps,pdf,jpg}} -t /usr/share/doc/$P
}

# 8.62 Findutils
findutils_pkg() {
    ./configure --prefix=/usr --localstatedir=/var/lib/locate
    make
    findutils_tests() { chown -R tester . && su tester -c "PATH=$PATH make check"; }
    t findutils_tests
    make install
}

# 8.63 Groff
groff_pkg() {
    PAGE=$GROFF_PAGE ./configure --prefix=/usr
    make
    t make check
    make install
}

# 8.64 GRUB
grub_pkg() {
    unset {C,CPP,CXX,LD}FLAGS
    echo depends bli part_gpt > grub-core/extra_deps.lst
    ./configure --prefix=/usr     \
                --sysconfdir=/etc \
                --disable-efiemu  \
                --disable-werror
    make
    t make check
    make install
    mv -v /etc/bash_completion.d/grub /usr/share/bash-completion/completions
}

# 8.65 Gzip
gzip_pkg() {
    ./configure --prefix=/usr
    make
    t make check
    make install
}

# 8.66 IPRoute2 (pas de suite de tests fonctionnelle)
iproute2_pkg() {
    sed -i /ARPD/d Makefile
    rm -fv man/man8/arpd.8
    make NETNS_RUN_DIR=/run/netns
    make SBINDIR=/usr/sbin install
    install -vDm644 COPYING README* -t /usr/share/doc/$P
}

# 8.67 Kbd
kbd_pkg() {
    patch -Np1 -i "$(find_file 'kbd-*-backspace-1.patch')"
    sed -i '/RESIZECONS_PROGS=/s/yes/no/' configure
    sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in
    ./configure --prefix=/usr --disable-vlock
    make
    make install
    cp -R -v docs/doc -T /usr/share/doc/$P
}

# 8.68 Libpipeline
libpipeline_pkg() {
    ./configure --prefix=/usr
    make
    t make check
    make install
}

# 8.69 Make
make_pkg() {
    ./configure --prefix=/usr
    make
    make_tests() { chown -R tester . && su tester -c "PATH=$PATH make check"; }
    t make_tests
    make install
}

# 8.70 Patch
patch_pkg() {
    ./configure --prefix=/usr
    make
    t make check
    make install
}

# 8.71 Tar
tar_pkg() {
    FORCE_UNSAFE_CONFIGURE=1 \
    ./configure --prefix=/usr
    make
    t make check
    make install
    make -C doc install-html docdir=/usr/share/doc/$P
}

# 8.72 Texinfo
texinfo_pkg() {
    sed 's/! $output_file eq/$output_file ne/' -i tp/Texinfo/Convert/*.pm
    ./configure --prefix=/usr
    make
    t make check
    make install
}

# 8.73 Vim
vim_pkg() {
    local vv; vv=$(echo "${P#vim-}" | cut -d. -f1,2 | tr -d .)   # 91
    echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
    ./configure --prefix=/usr
    make

    vim_tests() {
        chown -R tester .
        sed '/test_plugin_glvs/d' -i src/testdir/Make_all.mak
        su tester -c "TERM=xterm-256color LANG=en_US.UTF-8 make -j1 test" &> vim-test.log
        local rc=$?
        tail -n 20 vim-test.log
        return $rc
    }
    t vim_tests

    make install
    ln -sfv vim /usr/bin/vi
    for L in /usr/share/man/{,*/}man1/vim.1; do
        ln -sfv vim.1 $(dirname $L)/vi.1
    done
    ln -sfvn ../vim/vim$vv/doc /usr/share/doc/$P

    cat > /etc/vimrc << "EOF"
" Begin /etc/vimrc

" Ensure defaults are set before customizing settings, not after
source $VIMRUNTIME/defaults.vim
let skip_defaults_vim=1

set nocompatible
set backspace=2
set mouse=
syntax on
if (&term == "xterm") || (&term == "putty")
  set background=dark
endif

" End /etc/vimrc
EOF
}

# 8.74 / 8.75 MarkupSafe, Jinja2
pip_pkg() {
    pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
    pip3 install --no-index --find-links dist "$1"
}
markupsafe_pkg() { pip_pkg Markupsafe; }
jinja2_pkg()     { pip_pkg Jinja2; }

# 8.76 Udev from Systemd (archive systemd-x.y)
udev_pkg() {
    local udevlfs manpages
    udevlfs="$(find_file 'udev-lfs-*.tar.xz')"
    manpages="$(find_file 'systemd-man-pages-*.tar.xz')"

    sed -e 's/GROUP="render"/GROUP="video"/' \
        -e 's/GROUP="sgx", //'               \
        -i rules.d/50-udev-default.rules.in
    sed -i '/systemd-sysctl/s/^/#/' rules.d/99-systemd.rules.in
    sed -e '/NETWORK_DIRS/s/systemd/udev/' \
        -i src/libsystemd/sd-network/network-util.h

    mkdir -p build
    cd       build
    meson setup ..                  \
          --prefix=/usr             \
          --buildtype=release       \
          -D mode=release           \
          -D dev-kvm-mode=0660      \
          -D link-udev-shared=false \
          -D logind=false           \
          -D vconsole=false

    export udev_helpers=$(grep "'name' :" ../src/udev/meson.build | \
                          awk '{print $3}' | tr -d ",'" | grep -v 'udevadm')

    ninja udevadm systemd-hwdb                                           \
          $(ninja -n | grep -Eo '(src/(lib)?udev|rules.d|hwdb.d)/[^ ]*') \
          $(realpath libudev.so --relative-to .)                         \
          $udev_helpers

    install -vm755 -d {/usr/lib,/etc}/udev/{hwdb.d,rules.d,network}
    install -vm755 -d /usr/{lib,share}/pkgconfig
    install -vm755 udevadm                             /usr/bin/
    install -vm755 systemd-hwdb                        /usr/bin/udev-hwdb
    ln      -svfn  ../bin/udevadm                      /usr/sbin/udevd
    cp      -av    libudev.so{,*[0-9]}                 /usr/lib/
    install -vm644 ../src/libudev/libudev.h            /usr/include/
    install -vm644 src/libudev/*.pc                    /usr/lib/pkgconfig/
    install -vm644 src/udev/*.pc                       /usr/share/pkgconfig/
    install -vm644 ../src/udev/udev.conf               /etc/udev/
    install -vm644 rules.d/* ../rules.d/README         /usr/lib/udev/rules.d/
    install -vm644 $(find ../rules.d/*.rules \
                          -not -name '*power-switch*') /usr/lib/udev/rules.d/
    install -vm644 hwdb.d/*  ../hwdb.d/{*.hwdb,README} /usr/lib/udev/hwdb.d/
    install -vm755 $udev_helpers                       /usr/lib/udev
    install -vm644 ../network/99-default.link          /usr/lib/udev/network

    tar -xvf "$udevlfs"
    make -f "$(strip_ext "$udevlfs")/Makefile.lfs" install

    tar -xf "$manpages"                                                   \
        --no-same-owner --strip-components=1                              \
        -C /usr/share/man --wildcards '*/udev*' '*/libudev*'              \
                                      '*/systemd.link.5'                  \
                                      '*/systemd-'{hwdb,udevd.service}.8

    sed 's|systemd/network|udev/network|'                                 \
        /usr/share/man/man5/systemd.link.5                                \
      > /usr/share/man/man5/udev.link.5

    sed 's/systemd\(\\\?-\)/udev\1/' /usr/share/man/man8/systemd-hwdb.8   \
                                   > /usr/share/man/man8/udev-hwdb.8

    sed 's|lib.*udevd|sbin/udevd|'                                        \
        /usr/share/man/man8/systemd-udevd.service.8                       \
      > /usr/share/man/man8/udevd.8

    rm /usr/share/man/man*/systemd*
    unset udev_helpers

    # 8.76.2 Configuring Udev
    udev-hwdb update
}

# 8.77 Man-DB
man_db_pkg() {
    ./configure --prefix=/usr                 \
                --docdir=/usr/share/doc/$P    \
                --sysconfdir=/etc             \
                --disable-setuid              \
                --enable-cache-owner=bin      \
                --with-browser=/usr/bin/lynx  \
                --with-vgrind=/usr/bin/vgrind \
                --with-grap=/usr/bin/grap     \
                --with-systemdtmpfilesdir=    \
                --with-systemdsystemunitdir=
    make
    t make check
    make install
}

# 8.78 Procps-ng
procps_pkg() {
    ./configure --prefix=/usr               \
                --docdir=/usr/share/doc/$P  \
                --disable-static            \
                --disable-kill              \
                --enable-watch8bit
    make
    procps_tests() { chown -R tester . && su tester -c "PATH=$PATH make check"; }
    t procps_tests
    make install
}

# 8.79 Util-linux
util_linux_pkg() {
    ./configure --bindir=/usr/bin     \
                --libdir=/usr/lib     \
                --runstatedir=/run    \
                --sbindir=/usr/sbin   \
                --disable-chfn-chsh   \
                --disable-login       \
                --disable-nologin     \
                --disable-su          \
                --disable-setpriv     \
                --disable-runuser     \
                --disable-pylibmount  \
                --disable-liblastlog2 \
                --disable-static      \
                --without-python      \
                --without-systemd     \
                --without-systemdsystemunitdir        \
                ADJTIME_PATH=/var/lib/hwclock/adjtime \
                --docdir=/usr/share/doc/$P
    make
    # (tests/run.sh du livre : seulement une fois LFS démarré, pas dans le chroot)
    util_linux_tests() { touch /etc/fstab && chown -R tester . && su tester -c "make -k check"; }
    t util_linux_tests
    make install
}

# 8.80 E2fsprogs
e2fsprogs_pkg() {
    mkdir -v build
    cd       build
    ../configure --prefix=/usr       \
                 --sysconfdir=/etc   \
                 --enable-elf-shlibs \
                 --disable-libblkid  \
                 --disable-libuuid   \
                 --disable-uuidd     \
                 --disable-fsck
    make
    t make check
    make install
    rm -fv /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a

    gunzip -fv /usr/share/info/libext2fs.info.gz
    install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info

    makeinfo -o      doc/com_err.info ../lib/et/com_err.texinfo
    install -v -m644 doc/com_err.info /usr/share/info
    install-info --dir-file=/usr/share/info/dir /usr/share/info/com_err.info
}

# 8.81 Sysklogd
sysklogd_pkg() {
    ./configure --prefix=/usr      \
                --sysconfdir=/etc  \
                --runstatedir=/run \
                --without-logger   \
                --disable-static   \
                --docdir=/usr/share/doc/$P
    make
    make install

    cat > /etc/syslog.conf << "EOF"
# Begin /etc/syslog.conf

auth,authpriv.* -/var/log/auth.log
*.*;auth,authpriv.none -/var/log/sys.log
daemon.* -/var/log/daemon.log
kern.* -/var/log/kern.log
mail.* -/var/log/mail.log
user.* -/var/log/user.log
*.emerg *

# Do not open any internet ports.
secure_mode 2

# End /etc/syslog.conf
EOF
}

# 8.82 SysVinit
sysvinit_pkg() {
    patch -Np1 -i "$(find_file 'sysvinit-*-consolidated-1.patch')"
    make
    make install
}

# 8.84 Stripping (optionnel dans le livre)
# Les noms versionnés de save_usrlib / online_usrlib sont résolus sur le système
# (readlink) au lieu d'être écrits en dur : le livre demande de les adapter si
# une version diffère, sinon le système peut devenir inutilisable.
stripping() {
    if [ "$SKIP_STRIP" = 1 ]; then echo "SKIP_STRIP=1 : stripping ignoré"; return 0; fi
    cd /usr/lib
    real() { [ -e "/usr/lib/$1" ] && basename "$(readlink -f "/usr/lib/$1")" || true; }

    save_usrlib="$(cd /usr/lib; ls ld-linux*[^g])
                 $(real libc.so.6)
                 $(real libthread_db.so.1)
                 $(real libquadmath.so.0)
                 $(real libstdc++.so.6)
                 $(real libitm.so.1)
                 $(real libatomic.so.1)"

    for LIB in $save_usrlib; do
        objcopy --only-keep-debug --compress-debug-sections=zlib $LIB $LIB.dbg
        cp $LIB /tmp/$LIB
        strip --strip-debug /tmp/$LIB
        objcopy --add-gnu-debuglink=$LIB.dbg /tmp/$LIB
        install -vm755 /tmp/$LIB /usr/lib
        rm /tmp/$LIB
    done

    online_usrbin="bash find strip"
    online_usrlib="$(real libbfd.so)
                   $(real libsframe.so)
                   $(real libhistory.so)
                   $(real libncursesw.so)
                   $(real libm.so.6)
                   $(real libreadline.so)
                   $(real libz.so)
                   $(real libzstd.so)
                   $(cd /usr/lib; find libnss*.so* -type f)"

    for BIN in $online_usrbin; do
        cp /usr/bin/$BIN /tmp/$BIN
        strip --strip-debug /tmp/$BIN
        install -vm755 /tmp/$BIN /usr/bin
        rm /tmp/$BIN
    done

    for LIB in $online_usrlib; do
        cp /usr/lib/$LIB /tmp/$LIB
        strip --strip-debug /tmp/$LIB
        install -vm755 /tmp/$LIB /usr/lib
        rm /tmp/$LIB
    done

    # Les « file format not recognized » sur les scripts sont normaux
    for i in $(find /usr/lib -type f -name \*.so* ! -name \*dbg) \
             $(find /usr/lib -type f -name \*.a)                 \
             $(find /usr/{bin,sbin,libexec} -type f); do
        case "$online_usrbin $online_usrlib $save_usrlib" in
            *$(basename $i)* ) ;;
            * ) strip --strip-debug $i 2>/dev/null || true ;;
        esac
    done

    unset BIN LIB save_usrlib online_usrbin online_usrlib
}

# 8.85 Cleaning Up
cleanup() {
    # rm -rf /tmp/{*,.*} du livre, sans tenter de supprimer . et ..
    find /tmp -mindepth 1 -delete
    find /usr/lib /usr/libexec -name \*.la -delete
    # Le livre cible $(uname -m)-lfs-linux-gnu* : ici le vendeur de ton LFS_TGT
    find /usr -depth -name "$(uname -m)-$LFS_VENDOR-linux-gnu*" | xargs rm -rf
    if id tester &>/dev/null; then userdel -r tester; fi
}

build 08.58-kmod        kmod                   kmod_pkg
build 08.59-coreutils   coreutils              coreutils_pkg
build 08.59b-check      check                  check_pkg
build 08.60-diffutils   diffutils              diffutils_pkg
build 08.61-gawk        gawk                   gawk_pkg
build 08.62-findutils   findutils              findutils_pkg
build 08.63-groff       groff                  groff_pkg
build 08.64-grub        grub                   grub_pkg
build 08.65-gzip        gzip                   gzip_pkg
build 08.66-iproute2    iproute2               iproute2_pkg
build 08.67-kbd         kbd                    kbd_pkg
build 08.68-libpipeline libpipeline            libpipeline_pkg
build 08.69-make        make                   make_pkg
build 08.70-patch       patch                  patch_pkg
build 08.71-tar         tar                    tar_pkg
build 08.72-texinfo     texinfo                texinfo_pkg
build 08.73-vim         vim                    vim_pkg
build 08.74-markupsafe  markupsafe             markupsafe_pkg
build 08.75-jinja2      jinja2                 jinja2_pkg
build 08.76-udev        'systemd-[0-9]*.tar.gz' udev_pkg
build 08.77-man-db      man-db                 man_db_pkg
build 08.78-procps-ng   procps-ng              procps_pkg
build 08.79-util-linux  util-linux             util_linux_pkg
build 08.80-e2fsprogs   e2fsprogs              e2fsprogs_pkg
build 08.81-sysklogd    sysklogd               sysklogd_pkg
build 08.82-sysvinit    sysvinit               sysvinit_pkg
step  08.84-stripping                          stripping
step  08.85-cleanup                            cleanup

echo
echo "Chapitre 8 terminé."
[ -s "$LOGS/tests-summary.txt" ] && { echo "Résumé des tests à relire :"; cat "$LOGS/tests-summary.txt"; }
echo "Si ce n'est pas fait : passwd root (dans ./22_enter_chroot.sh)"
echo "Suite : chapitre 9 (bootscripts, configuration)."
