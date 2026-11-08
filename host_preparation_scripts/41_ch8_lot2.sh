#!/bin/bash
# LFS 12.4 - Chapitre 8, lot 2 : 8.20 Binutils -> 8.36 Bash (DANS le chroot)
#   Sur l'hôte :  ./22_enter_chroot.sh 41_ch8_lot2.sh
#   Options    :  TESTS=critical|all|none
# Les tests de GCC (TESTS=critical) sont très longs : compter plusieurs heures.
source "$(dirname "$0")/chroot_lib.sh"
chroot_init
need_stamp 08.19-pkgconf

# 8.20 Binutils
binutils_pkg() {
    mkdir -v build
    cd       build
    ../configure --prefix=/usr       \
                 --sysconfdir=/etc   \
                 --enable-ld=default \
                 --enable-plugins    \
                 --enable-shared     \
                 --disable-werror    \
                 --enable-64-bit-bfd \
                 --enable-new-dtags  \
                 --with-system-zlib  \
                 --enable-default-hash-style=gnu
    make tooldir=/usr

    binutils_tests() {
        make -k check
        grep '^FAIL:' $(find -name '*.log') || true
    }
    t binutils_tests

    make tooldir=/usr install
    rm -rfv /usr/lib/lib{bfd,ctf,ctf-nobfd,gprofng,opcodes,sframe}.a \
            /usr/share/doc/gprofng/
}

# 8.21 GMP
gmp_pkg() {
    sed -i '/long long t1;/,+1s/()/(...)/' configure
    ./configure --prefix=/usr    \
                --enable-cxx     \
                --disable-static \
                --docdir=/usr/share/doc/$P
    make
    make html

    gmp_tests() {
        make check 2>&1 | tee gmp-check-log
        local n; n=$(awk '/# PASS:/{total+=$3} ; END{print total}' gmp-check-log)
        echo "GMP : $n tests réussis (le livre en attend au moins 199)" | tee -a "$LOGS/tests-summary.txt"
    }
    t gmp_tests

    make install
    make install-html
}

# 8.22 MPFR
mpfr_pkg() {
    ./configure --prefix=/usr        \
                --disable-static     \
                --enable-thread-safe \
                --docdir=/usr/share/doc/$P
    make
    make html
    t make check
    make install
    make install-html
}

# 8.23 MPC
mpc_pkg() {
    ./configure --prefix=/usr    \
                --disable-static \
                --docdir=/usr/share/doc/$P
    make
    make html
    t make check
    make install
    make install-html
}

# 8.24 Attr
attr_pkg() {
    ./configure --prefix=/usr     \
                --disable-static  \
                --sysconfdir=/etc \
                --docdir=/usr/share/doc/$P
    make
    t make check
    make install
}

# 8.25 Acl
acl_pkg() {
    ./configure --prefix=/usr    \
                --disable-static \
                --docdir=/usr/share/doc/$P
    make
    t make check
    make install
}

# 8.26 Libcap
libcap_pkg() {
    sed -i '/install -m.*STA/d' libcap/Makefile
    make prefix=/usr lib=lib
    t make test
    make prefix=/usr lib=lib install
}

# 8.27 Libxcrypt (sans l'API obsolète, optionnelle dans le livre)
libxcrypt_pkg() {
    ./configure --prefix=/usr                \
                --enable-hashes=strong,glibc \
                --enable-obsolete-api=no     \
                --disable-static             \
                --disable-failure-tokens
    make
    t make check
    make install
}

# 8.28 Shadow
shadow_pkg() {
    sed -i 's/groups$(EXEEXT) //' src/Makefile.in
    find man -name Makefile.in -exec sed -i 's/groups\.1 / /'   {} \;
    find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
    find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \;

    sed -e 's:#ENCRYPT_METHOD DES:ENCRYPT_METHOD YESCRYPT:' \
        -e 's:/var/spool/mail:/var/mail:'                   \
        -e '/PATH=/{s@/sbin:@@;s@/bin:@@}'                  \
        -i etc/login.defs

    touch /usr/bin/passwd
    ./configure --sysconfdir=/etc   \
                --disable-static    \
                --with-{b,yes}crypt \
                --without-libbsd    \
                --with-group-name-max-length=32
    make
    make exec_prefix=/usr install
    make -C man install-man

    pwconv
    grpconv
    mkdir -p /etc/default
    useradd -D --gid 999

    # « passwd root » est interactif : à faire à la main (voir la fin du script)
}

# 8.29 GCC
gcc_sanity() {
    echo 'int main(){}' | cc -x c - -v -Wl,--verbose &> dummy.log
    local interp; interp="$(readelf -l a.out | grep ': /lib' || true)"
    echo "$interp"
    [[ $interp == *"program interpreter: /lib"* ]] || { echo "SANITY: interpréteur incorrect"; return 1; }

    local crt; crt="$(grep -E -o '/usr/lib.*/S?crt[1in].*succeeded' dummy.log || true)"
    echo "$crt"
    [ "$(grep -c succeeded <<<"$crt")" -eq 3 ] || { echo "SANITY: fichiers crt incorrects"; return 1; }

    grep -B4 '^ /usr/include' dummy.log        || { echo "SANITY: chemins d'en-têtes incorrects"; return 1; }
    grep 'SEARCH.*/usr/lib' dummy.log | sed 's|; |\n|g' || true

    grep "/lib.*/libc.so.6 " dummy.log || true
    grep -q "attempt to open /usr/lib/libc.so.6 succeeded" dummy.log \
                                               || { echo "SANITY: mauvaise libc"; return 1; }
    grep found dummy.log || true
    grep -q "found ld-.* at /usr/lib/ld-" dummy.log \
                                               || { echo "SANITY: mauvais chargeur dynamique"; return 1; }
    rm -v a.out dummy.log
}

gcc_pkg() {
    local ver=${P#gcc-}
    case $(uname -m) in
      x86_64)
        sed -e '/m64=/s/lib64/lib/' \
            -i.orig gcc/config/i386/t-linux64
      ;;
    esac

    mkdir -v build
    cd       build
    ../configure --prefix=/usr            \
                 LD=ld                    \
                 --enable-languages=c,c++ \
                 --enable-default-pie     \
                 --enable-default-ssp     \
                 --enable-host-pie        \
                 --disable-multilib       \
                 --disable-bootstrap      \
                 --disable-fixincludes    \
                 --with-system-zlib
    make

    gcc_tests() {
        ulimit -s -H unlimited
        sed -e '/cpython/d' -i ../gcc/testsuite/gcc.dg/plugin/plugin.exp
        chown -R tester .
        su tester -c "PATH=$PATH make -k check" || true
        ../contrib/test_summary | grep -A7 Summ | tee "$LOGS/gcc-test-summary.txt"
        echo "GCC : résumé des tests dans gcc-test-summary.txt (à comparer au livre)" >>"$LOGS/tests-summary.txt"
    }
    t gcc_tests

    make install
    chown -v -R root:root \
        /usr/lib/gcc/$(gcc -dumpmachine)/$ver/include{,-fixed}
    ln -svfr /usr/bin/cpp /usr/lib
    ln -sfv gcc.1 /usr/share/man/man1/cc.1
    ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/$ver/liblto_plugin.so \
            /usr/lib/bfd-plugins/

    gcc_sanity

    mkdir -pv /usr/share/gdb/auto-load/usr/lib
    mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib
}

# 8.30 Ncurses
ncurses_pkg() {
    local so; so=$(echo "${P#ncurses-}" | cut -d- -f1)   # 6.5
    ./configure --prefix=/usr           \
                --mandir=/usr/share/man \
                --with-shared           \
                --without-debug         \
                --without-normal        \
                --with-cxx-shared       \
                --enable-pc-files       \
                --with-pkg-config-libdir=/usr/lib/pkgconfig
    make
    make DESTDIR=$PWD/dest install
    install -vm755 dest/usr/lib/libncursesw.so.$so /usr/lib
    rm -v  dest/usr/lib/libncursesw.so.$so
    sed -e 's/^#if.*XOPEN.*$/#if 1/' \
        -i dest/usr/include/curses.h
    cp -av dest/* /

    for lib in ncurses form panel menu ; do
        ln -sfv lib${lib}w.so /usr/lib/lib${lib}.so
        ln -sfv ${lib}w.pc    /usr/lib/pkgconfig/${lib}.pc
    done
    ln -sfv libncursesw.so /usr/lib/libcurses.so

    cp -v -R doc -T /usr/share/doc/$P
}

# 8.31 Sed
sed_pkg() {
    ./configure --prefix=/usr
    make
    make html
    sed_tests() { chown -R tester . && su tester -c "PATH=$PATH make check"; }
    t sed_tests
    make install
    install -d -m755           /usr/share/doc/$P
    install -m644 doc/sed.html /usr/share/doc/$P
}

# 8.32 Psmisc
psmisc_pkg() {
    ./configure --prefix=/usr
    make
    t make check
    make install
}

# 8.33 Gettext
gettext_pkg() {
    ./configure --prefix=/usr    \
                --disable-static \
                --docdir=/usr/share/doc/$P
    make
    t make check
    make install
    chmod -v 0755 /usr/lib/preloadable_libintl.so
}

# 8.34 Bison
bison_pkg() {
    ./configure --prefix=/usr --docdir=/usr/share/doc/$P
    make
    t make check
    make install
}

# 8.35 Grep
grep_pkg() {
    sed -i "s/echo/#echo/" src/egrep.sh
    ./configure --prefix=/usr
    make
    t make check
    make install
}

# 8.36 Bash
bash_pkg() {
    ./configure --prefix=/usr             \
                --without-bash-malloc     \
                --with-installed-readline \
                --docdir=/usr/share/doc/$P
    make

    bash_tests() {
        chown -R tester .
        LC_ALL=C.UTF-8 su -s /usr/bin/expect tester << "EOF"
set timeout -1
spawn make tests
expect eof
lassign [wait] _ _ _ value
exit $value
EOF
    }
    t bash_tests

    make install
    # « exec /usr/bin/bash --login » du livre : le lot suivant démarre déjà le nouveau bash
}

build 08.20-binutils   binutils   binutils_pkg
build 08.21-gmp        gmp        gmp_pkg
build 08.22-mpfr       mpfr       mpfr_pkg
build 08.23-mpc        mpc        mpc_pkg
build 08.24-attr       attr       attr_pkg
build 08.25-acl        acl        acl_pkg
build 08.26-libcap     libcap     libcap_pkg
build 08.27-libxcrypt  libxcrypt  libxcrypt_pkg
build 08.28-shadow     shadow     shadow_pkg
build 08.29-gcc        gcc        gcc_pkg
build 08.30-ncurses    ncurses    ncurses_pkg
build 08.31-sed        sed        sed_pkg
build 08.32-psmisc     psmisc     psmisc_pkg
build 08.33-gettext    gettext    gettext_pkg
build 08.34-bison      bison      bison_pkg
build 08.35-grep       grep       grep_pkg
build 08.36-bash       bash       bash_pkg

echo
echo "Lot 2 terminé."
echo "À faire une fois à la main (8.28) :  ./22_enter_chroot.sh  puis  passwd root"
echo "Suite : ./22_enter_chroot.sh 42_ch8_lot3.sh"
