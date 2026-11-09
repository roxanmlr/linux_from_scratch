#!/bin/bash
# LFS 12.4 - Chapitre 8, lot 3 : 8.37 Libtool -> 8.57 Meson (DANS le chroot)
#   Sur l'hôte :  ./22_enter_chroot.sh 42_ch8_lot3.sh
#   Options    :  TESTS=critical|all|none
source "$(dirname "$0")/chroot_lib.sh"
chroot_init
need_stamp 08.36-bash

# 8.37 Libtool
libtool_pkg() {
    ./configure --prefix=/usr
    make
    t make check
    make install
    rm -fv /usr/lib/libltdl.a
}

# 8.38 GDBM
gdbm_pkg() {
    ./configure --prefix=/usr    \
                --disable-static \
                --enable-libgdbm-compat
    make
    t make check
    make install
}

# 8.39 Gperf
gperf_pkg() {
    ./configure --prefix=/usr --docdir=/usr/share/doc/$P
    make
    t make check
    make install
}

# 8.40 Expat
expat_pkg() {
    ./configure --prefix=/usr    \
                --disable-static \
                --docdir=/usr/share/doc/$P
    make
    t make check
    make install
    install -v -m644 doc/*.{html,css} /usr/share/doc/$P
}

# 8.41 Inetutils
inetutils_pkg() {
    sed -i 's/def HAVE_TERMCAP_TGETENT/ 1/' telnet/telnet.c
    ./configure --prefix=/usr        \
                --bindir=/usr/bin    \
                --localstatedir=/var \
                --disable-logger     \
                --disable-whois      \
                --disable-rcp        \
                --disable-rexec      \
                --disable-rlogin     \
                --disable-rsh        \
                --disable-servers
    make
    t make check
    make install
    mv -v /usr/{,s}bin/ifconfig
}

# 8.42 Less
less_pkg() {
    ./configure --prefix=/usr --sysconfdir=/etc
    make
    t make check
    make install
}

# 8.43 Perl
perl_pkg() {
    local pv; pv=$(echo "${P#perl-}" | cut -d. -f1,2)    # 5.42
    export BUILD_ZLIB=False
    export BUILD_BZIP2=0
    sh Configure -des                                        \
                 -D prefix=/usr                              \
                 -D vendorprefix=/usr                        \
                 -D privlib=/usr/lib/perl5/$pv/core_perl     \
                 -D archlib=/usr/lib/perl5/$pv/core_perl     \
                 -D sitelib=/usr/lib/perl5/$pv/site_perl     \
                 -D sitearch=/usr/lib/perl5/$pv/site_perl    \
                 -D vendorlib=/usr/lib/perl5/$pv/vendor_perl \
                 -D vendorarch=/usr/lib/perl5/$pv/vendor_perl \
                 -D man1dir=/usr/share/man/man1              \
                 -D man3dir=/usr/share/man/man3              \
                 -D pager="/usr/bin/less -isR"               \
                 -D useshrplib                               \
                 -D usethreads
    make
    perl_tests() { TEST_JOBS=$(nproc) make test_harness; }
    t perl_tests
    make install
    unset BUILD_ZLIB BUILD_BZIP2
}

# 8.44 XML::Parser
xml_parser_pkg() {
    perl Makefile.PL
    make
    t make test
    make install
}

# 8.45 Intltool
intltool_pkg() {
    sed -i 's:\\\${:\\\$\\{:' intltool-update.in
    ./configure --prefix=/usr
    make
    t make check
    make install
    install -v -Dm644 doc/I18N-HOWTO /usr/share/doc/$P/I18N-HOWTO
}

# 8.46 Autoconf
autoconf_pkg() {
    ./configure --prefix=/usr
    make
    t make check
    make install
}

# 8.47 Automake
automake_pkg() {
    ./configure --prefix=/usr --docdir=/usr/share/doc/$P
    make
    t make -j$(($(nproc)>4?$(nproc):4)) check
    make install
}

# 8.48 OpenSSL
openssl_pkg() {
    ./config --prefix=/usr         \
             --openssldir=/etc/ssl \
             --libdir=lib          \
             shared                \
             zlib-dynamic
    make
    openssl_tests() { HARNESS_JOBS=$(nproc) make test; }
    t openssl_tests
    sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
    make MANSUFFIX=ssl install
    rm -rf /usr/share/doc/$P
    mv -v /usr/share/doc/openssl /usr/share/doc/$P
    cp -vfr doc/* /usr/share/doc/$P
}

# 8.49 Libelf from Elfutils
libelf_pkg() {
    ./configure --prefix=/usr        \
                --disable-debuginfod \
                --enable-libdebuginfod=dummy
    make
    t make check
    make -C libelf install
    install -vm644 config/libelf.pc /usr/lib/pkgconfig
    rm -f /usr/lib/libelf.a
}

# 8.50 Libffi
libffi_pkg() {
    ./configure --prefix=/usr    \
                --disable-static \
                --with-gcc-arch=native
    make
    t make check
    make install
}

# 8.51 Python
python_pkg() {
    local v=${P#Python-}
    ./configure --prefix=/usr          \
                --enable-shared        \
                --with-system-expat    \
                --enable-optimizations \
                --without-static-libpython
    make
    t make test TESTOPTS="--timeout 120"
    make install

    cat > /etc/pip.conf << EOF
[global]
root-user-action = ignore
disable-pip-version-check = true
EOF

    install -v -dm755 /usr/share/doc/python-$v/html
    tar --strip-components=1  \
        --no-same-owner       \
        --no-same-permissions \
        -C /usr/share/doc/python-$v/html \
        -xvf "$(find_file "python-$v-docs-html.tar.bz2")"
}

# 8.52 à 8.55 : modules Python installés avec pip, même recette
pip_pkg() {   # pip_pkg <nom du module>
    pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
    pip3 install --no-index --find-links dist "$1"
}
flit_core_pkg()  { pip_pkg flit_core; }
packaging_pkg()  { pip_pkg packaging; }
wheel_pkg()      { pip_pkg wheel; }
setuptools_pkg() { pip_pkg setuptools; }

# 8.56 Ninja (pas de tests possibles dans le chroot)
ninja_pkg() {
    python3 configure.py --bootstrap --verbose
    install -vm755 ninja /usr/bin/
    install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
    install -vDm644 misc/zsh-completion  /usr/share/zsh/site-functions/_ninja
}

# 8.57 Meson
meson_pkg() {
    pip_pkg meson
    install -vDm644 data/shell-completions/bash/meson /usr/share/bash-completion/completions/meson
    install -vDm644 data/shell-completions/zsh/_meson /usr/share/zsh/site-functions/_meson
}

build 08.37-libtool     libtool      libtool_pkg
build 08.38-gdbm        gdbm         gdbm_pkg
build 08.39-gperf       gperf        gperf_pkg
build 08.40-expat       expat        expat_pkg
build 08.41-inetutils   inetutils    inetutils_pkg
build 08.42-less        less         less_pkg
build 08.43-perl        perl         perl_pkg
build 08.44-xml-parser  XML-Parser   xml_parser_pkg
build 08.45-intltool    intltool     intltool_pkg
build 08.46-autoconf    autoconf     autoconf_pkg
build 08.47-automake    automake     automake_pkg
build 08.48-openssl     openssl      openssl_pkg
build 08.49-libelf      elfutils     libelf_pkg
build 08.50-libffi      libffi       libffi_pkg
build 08.51-python      Python       python_pkg
build 08.52-flit-core   flit_core    flit_core_pkg
build 08.53-packaging   packaging    packaging_pkg
build 08.54-wheel       wheel        wheel_pkg
build 08.55-setuptools  setuptools   setuptools_pkg
build 08.56-ninja       ninja        ninja_pkg
build 08.57-meson       meson        meson_pkg

echo
echo "Lot 3 terminé. Suite : ./22_enter_chroot.sh 43_ch8_lot4.sh"
