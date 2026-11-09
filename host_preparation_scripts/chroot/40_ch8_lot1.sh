#!/bin/bash
# LFS 12.4 - Chapitre 8, lot 1 : 8.3 Man-pages -> 8.19 Pkgconf (DANS le chroot)
#   Sur l'hôte :  ./22_enter_chroot.sh 40_ch8_lot1.sh
#   Options    :  TESTS=critical|all|none   LFS_TZ=Europe/Paris   FULL_LOCALES=1
# Reprenable : relancer reprend à la première étape non terminée.
source "$(dirname "$0")/chroot_lib.sh"
chroot_init
need_stamp 07.13-cleanup

export LFS_TZ="${LFS_TZ:-Europe/Paris}"
export FULL_LOCALES="${FULL_LOCALES:-0}"

# 8.3 Man-pages
man_pages() {
    rm -v man3/crypt*
    make -R GIT=false prefix=/usr install
}

# 8.4 Iana-Etc
iana_etc() {
    cp services protocols /etc
}

# 8.5 Glibc
glibc_pkg() {
    patch -Np1 -i "$(find_file 'glibc-*-fhs-1.patch')"

    sed -e '/unistd.h/i #include <string.h>' \
        -e '/libc_rwlock_init/c\
  __libc_rwlock_define_initialized (, reset_lock);\
  memcpy (&lock, &reset_lock, sizeof (lock));' \
        -i stdlib/abort.c

    mkdir -v build
    cd       build
    echo "rootsbindir=/usr/sbin" > configparms

    ../configure --prefix=/usr                   \
                 --disable-werror                \
                 --disable-nscd                  \
                 libc_cv_slibdir=/usr/lib        \
                 --enable-stack-protector=strong \
                 --enable-kernel=5.4
    make

    # Tests critiques : quelques échecs sont attendus (voir le livre)
    t make check
    grep "Timed out" $(find -name \*.out) || true

    touch /etc/ld.so.conf
    sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile
    make install
    sed '/RTLDLIST=/s@/usr@@g' -i /usr/bin/ldd

    # Locales
    if [ "$FULL_LOCALES" = 1 ]; then
        make localedata/install-locales
    else
        localedef -i C -f UTF-8 C.UTF-8
        localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8
        localedef -i de_DE -f ISO-8859-1 de_DE
        localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro
        localedef -i de_DE -f UTF-8 de_DE.UTF-8
        localedef -i el_GR -f ISO-8859-7 el_GR
        localedef -i en_GB -f ISO-8859-1 en_GB
        localedef -i en_GB -f UTF-8 en_GB.UTF-8
        localedef -i en_HK -f ISO-8859-1 en_HK
        localedef -i en_PH -f ISO-8859-1 en_PH
        localedef -i en_US -f ISO-8859-1 en_US
        localedef -i en_US -f UTF-8 en_US.UTF-8
        localedef -i es_ES -f ISO-8859-15 es_ES@euro
        localedef -i es_MX -f ISO-8859-1 es_MX
        localedef -i fa_IR -f UTF-8 fa_IR
        localedef -i fr_FR -f ISO-8859-1 fr_FR
        localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro
        localedef -i fr_FR -f UTF-8 fr_FR.UTF-8
        localedef -i is_IS -f ISO-8859-1 is_IS
        localedef -i is_IS -f UTF-8 is_IS.UTF-8
        localedef -i it_IT -f ISO-8859-1 it_IT
        localedef -i it_IT -f ISO-8859-15 it_IT@euro
        localedef -i it_IT -f UTF-8 it_IT.UTF-8
        localedef -i ja_JP -f EUC-JP ja_JP
        localedef -i ja_JP -f UTF-8 ja_JP.UTF-8 || true   # avertissement connu, cf. livre
        localedef -i nl_NL@euro -f ISO-8859-15 nl_NL@euro
        localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R
        localedef -i ru_RU -f UTF-8 ru_RU.UTF-8
        localedef -i se_NO -f UTF-8 se_NO.UTF-8
        localedef -i ta_IN -f UTF-8 ta_IN.UTF-8
        localedef -i tr_TR -f UTF-8 tr_TR.UTF-8
        localedef -i zh_CN -f GB18030 zh_CN.GB18030
        localedef -i zh_HK -f BIG5-HKSCS zh_HK.BIG5-HKSCS
        localedef -i zh_TW -f UTF-8 zh_TW.UTF-8
    fi

    # 8.5.2.1 nsswitch.conf
    cat > /etc/nsswitch.conf << "EOF"
# Begin /etc/nsswitch.conf

passwd: files
group: files
shadow: files

hosts: files dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

# End /etc/nsswitch.conf
EOF

    # 8.5.2.2 Time zone data
    tar -xf "$(find_file 'tzdata*.tar.gz')"

    ZONEINFO=/usr/share/zoneinfo
    mkdir -pv $ZONEINFO/{posix,right}

    for tz in etcetera southamerica northamerica europe africa antarctica \
              asia australasia backward; do
        zic -L /dev/null   -d $ZONEINFO       ${tz}
        zic -L /dev/null   -d $ZONEINFO/posix ${tz}
        zic -L leapseconds -d $ZONEINFO/right ${tz}
    done

    cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
    zic -d $ZONEINFO -p America/New_York
    unset ZONEINFO tz

    # tzselect est interactif : on prend LFS_TZ
    [ -e "/usr/share/zoneinfo/$LFS_TZ" ] || { echo "fuseau inconnu : $LFS_TZ"; exit 1; }
    ln -sfv "/usr/share/zoneinfo/$LFS_TZ" /etc/localtime

    # 8.5.2.3 Dynamic loader
    cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib

EOF
    cat >> /etc/ld.so.conf << "EOF"
# Add an include directory
include /etc/ld.so.conf.d/*.conf

EOF
    mkdir -pv /etc/ld.so.conf.d
}

# 8.6 Zlib
zlib_pkg() {
    ./configure --prefix=/usr
    make
    t make check
    make install
    rm -fv /usr/lib/libz.a
}

# 8.7 Bzip2
bzip2_pkg() {
    patch -Np1 -i "$(find_file 'bzip2-*-install_docs-1.patch')"
    sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
    sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
    make -f Makefile-libbz2_so
    make clean
    make
    make PREFIX=/usr install
    cp -av libbz2.so.* /usr/lib
    ln -sfv libbz2.so.${P#bzip2-} /usr/lib/libbz2.so
    cp -v bzip2-shared /usr/bin/bzip2
    for i in /usr/bin/{bzcat,bunzip2}; do
        ln -sfv bzip2 $i
    done
    rm -fv /usr/lib/libbz2.a
}

# 8.8 Xz
xz_pkg() {
    ./configure --prefix=/usr    \
                --disable-static \
                --docdir=/usr/share/doc/$P
    make
    t make check
    make install
}

# 8.9 Lz4
lz4_pkg() {
    make BUILD_STATIC=no PREFIX=/usr
    t make -j1 check
    make BUILD_STATIC=no PREFIX=/usr install
}

# 8.10 Zstd
zstd_pkg() {
    make prefix=/usr
    t make check
    make prefix=/usr install
    rm -fv /usr/lib/libzstd.a
}

# 8.11 File
file_pkg() {
    ./configure --prefix=/usr
    make
    t make check
    make install
}

# 8.12 Readline
readline_pkg() {
    sed -i '/MV.*old/d' Makefile.in
    sed -i '/{OLDSUFF}/c:' support/shlib-install
    sed -i 's/-Wl,-rpath,[^ ]*//' support/shobj-conf
    ./configure --prefix=/usr    \
                --disable-static \
                --with-curses    \
                --docdir=/usr/share/doc/$P
    make SHLIB_LIBS="-lncursesw"
    make install
    install -v -m644 doc/*.{ps,pdf,html,dvi} /usr/share/doc/$P
}

# 8.13 M4
m4_pkg() {
    ./configure --prefix=/usr
    make
    t make check
    make install
}

# 8.14 Bc
bc_pkg() {
    CC='gcc -std=c99' ./configure --prefix=/usr -G -O3 -r
    make
    t make test
    make install
}

# 8.15 Flex
flex_pkg() {
    ./configure --prefix=/usr                  \
                --docdir=/usr/share/doc/$P     \
                --disable-static
    make
    t make check
    make install
    ln -sfv flex   /usr/bin/lex
    ln -sfv flex.1 /usr/share/man/man1/lex.1
}

# 8.16 Tcl  (archive tcl8.6.x-src.tar.gz, dossier tcl8.6.x)
tcl_pkg() {
    local ver=${P#tcl} tdbc itcl
    SRCDIR=$(pwd)
    tdbc=$(cd pkgs && ls -d tdbc1*)
    itcl=$(cd pkgs && ls -d itcl4*)
    cd unix
    ./configure --prefix=/usr           \
                --mandir=/usr/share/man \
                --disable-rpath
    make

    sed -e "s|$SRCDIR/unix|/usr/lib|" \
        -e "s|$SRCDIR|/usr/include|"  \
        -i tclConfig.sh

    sed -e "s|$SRCDIR/unix/pkgs/$tdbc|/usr/lib/$tdbc|" \
        -e "s|$SRCDIR/pkgs/$tdbc/generic|/usr/include|" \
        -e "s|$SRCDIR/pkgs/$tdbc/library|/usr/lib/tcl8.6|" \
        -e "s|$SRCDIR/pkgs/$tdbc|/usr/include|"         \
        -i pkgs/$tdbc/tdbcConfig.sh

    sed -e "s|$SRCDIR/unix/pkgs/$itcl|/usr/lib/$itcl|" \
        -e "s|$SRCDIR/pkgs/$itcl/generic|/usr/include|" \
        -e "s|$SRCDIR/pkgs/$itcl|/usr/include|"         \
        -i pkgs/$itcl/itclConfig.sh

    unset SRCDIR
    t make test
    make install
    chmod 644 /usr/lib/libtclstub8.6.a
    chmod -v u+w /usr/lib/libtcl8.6.so
    make install-private-headers
    ln -sfv tclsh8.6 /usr/bin/tclsh
    mv /usr/share/man/man3/{Thread,Tcl_Thread}.3
    cd ..
    tar -xf "$(find_file "tcl$ver-html.tar.gz")" --strip-components=1
    mkdir -v -p /usr/share/doc/tcl-$ver
    cp -v -r ./html/* /usr/share/doc/tcl-$ver
}

# 8.17 Expect  (archive expect5.45.x.tar.gz)
expect_pkg() {
    # Vérification bloquante du livre : les PTY doivent fonctionner dans le chroot
    # (la sortie d'un PTY finit par \r\n : on retire le \r avant de comparer)
    local out
    out="$(python3 -c 'from pty import spawn; spawn(["echo", "ok"])' 2>&1 | tr -d '\r' || true)"
    echo "test PTY : [$out]"
    [ "$out" = ok ] \
        || { echo "PTY non fonctionnels : /dev/pts est-il monté ? (21_mount_vfs.sh)"; exit 1; }
    patch -Np1 -i "$(find_file 'expect-*-gcc15-1.patch')"
    ./configure --prefix=/usr           \
                --with-tcl=/usr/lib     \
                --enable-shared         \
                --disable-rpath         \
                --mandir=/usr/share/man \
                --with-tclinclude=/usr/include
    make
    t make test
    make install
    ln -svf $P/lib$P.so /usr/lib
}

# 8.18 DejaGNU
dejagnu_pkg() {
    mkdir -v build
    cd       build
    ../configure --prefix=/usr
    makeinfo --html --no-split -o doc/dejagnu.html ../doc/dejagnu.texi
    makeinfo --plaintext       -o doc/dejagnu.txt  ../doc/dejagnu.texi
    t make check
    make install
    install -v -dm755  /usr/share/doc/$P
    install -v -m644   doc/dejagnu.{html,txt} /usr/share/doc/$P
}

# 8.19 Pkgconf
pkgconf_pkg() {
    ./configure --prefix=/usr    \
                --disable-static \
                --docdir=/usr/share/doc/$P
    make
    make install
    ln -sfv pkgconf   /usr/bin/pkg-config
    ln -sfv pkgconf.1 /usr/share/man/man1/pkg-config.1
}

build 08.03-man-pages  man-pages             man_pages
build 08.04-iana-etc   iana-etc              iana_etc
build 08.05-glibc      glibc                 glibc_pkg
build 08.06-zlib       zlib                  zlib_pkg
build 08.07-bzip2      bzip2                 bzip2_pkg
build 08.08-xz         xz                    xz_pkg
build 08.09-lz4        lz4                   lz4_pkg
build 08.10-zstd       zstd                  zstd_pkg
build 08.11-file       file                  file_pkg
build 08.12-readline   readline              readline_pkg
build 08.13-m4         m4                    m4_pkg
build 08.14-bc         bc                    bc_pkg
build 08.15-flex       flex                  flex_pkg
build 08.16-tcl        'tcl*-src.tar.gz'     tcl_pkg
build 08.17-expect     'expect5*.tar.gz'     expect_pkg
build 08.18-dejagnu    dejagnu               dejagnu_pkg
build 08.19-pkgconf    pkgconf               pkgconf_pkg

echo
echo "Lot 1 terminé. Suite : ./22_enter_chroot.sh 41_ch8_lot2.sh"
