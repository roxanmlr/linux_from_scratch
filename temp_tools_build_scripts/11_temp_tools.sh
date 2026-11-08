#!/usr/bin/env bash

source "$(dirname "$(realpath "$0")")/build_lib.sh"
ft_linux_init "$@"

[ -e "$STAMPS/05.6-libstdcxx" ] || die "chapitre 5 incomplet, lance d'abord ./10_cross_toolchain.sh"

# 6.2 M4
m4_pkg() {
    ./configure --prefix=/usr   \
                --host=$LFS_TGT \
                --build=$(build-aux/config.guess)
    make
    make DESTDIR=$LFS install
}

# 6.3 Ncurses
ncurses_pkg() {
    mkdir build
    pushd build
      ../configure --prefix=$LFS/tools AWK=gawk
      make -C include
      make -C progs tic
      install progs/tic $LFS/tools/bin
    popd

    ./configure --prefix=/usr                \
                --host=$LFS_TGT              \
                --build=$(./config.guess)    \
                --mandir=/usr/share/man      \
                --with-manpage-format=normal \
                --with-shared                \
                --without-normal             \
                --with-cxx-shared            \
                --without-debug              \
                --without-ada                \
                --disable-stripping          \
                AWK=gawk
    make
    make DESTDIR=$LFS install
    ln -sfv libncursesw.so $LFS/usr/lib/libncurses.so
    sed -e 's/^#if.*XOPEN.*$/#if 1/' \
        -i $LFS/usr/include/curses.h
}

# 6.4 Bash
bash_pkg() {
    ./configure --prefix=/usr                      \
                --build=$(sh support/config.guess) \
                --host=$LFS_TGT                    \
                --without-bash-malloc
    make
    make DESTDIR=$LFS install
    ln -sfv bash $LFS/bin/sh
}

# 6.5 Coreutils
coreutils_pkg() {
    ./configure --prefix=/usr                     \
                --host=$LFS_TGT                   \
                --build=$(build-aux/config.guess) \
                --enable-install-program=hostname \
                --enable-no-install-program=kill,uptime
    make
    make DESTDIR=$LFS install

    mv -v $LFS/usr/bin/chroot              $LFS/usr/sbin
    mkdir -pv $LFS/usr/share/man/man8
    mv -v $LFS/usr/share/man/man1/chroot.1 $LFS/usr/share/man/man8/chroot.8
    sed -i 's/"1"/"8"/'                    $LFS/usr/share/man/man8/chroot.8
}

# 6.6 Diffutils
diffutils_pkg() {
    ./configure --prefix=/usr   \
                --host=$LFS_TGT \
                gl_cv_func_strcasecmp_works=y \
                --build=$(./build-aux/config.guess)
    make
    make DESTDIR=$LFS install
}

# 6.7 File
file_pkg() {
    mkdir build
    pushd build
      ../configure --disable-bzlib      \
                   --disable-libseccomp \
                   --disable-xzlib      \
                   --disable-zlib
      make
    popd

    ./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess)
    make FILE_COMPILE=$(pwd)/build/src/file
    make DESTDIR=$LFS install
    rm -fv $LFS/usr/lib/libmagic.la
}

# 6.8 Findutils
findutils_pkg() {
    ./configure --prefix=/usr                   \
                --localstatedir=/var/lib/locate \
                --host=$LFS_TGT                 \
                --build=$(build-aux/config.guess)
    make
    make DESTDIR=$LFS install
}

# 6.9 Gawk
gawk_pkg() {
    sed -i 's/extras//' Makefile.in
    ./configure --prefix=/usr   \
                --host=$LFS_TGT \
                --build=$(build-aux/config.guess)
    make
    make DESTDIR=$LFS install
}

# 6.10 Grep
grep_pkg() {
    ./configure --prefix=/usr   \
                --host=$LFS_TGT \
                --build=$(./build-aux/config.guess)
    make
    make DESTDIR=$LFS install
}

# 6.11 Gzip
gzip_pkg() {
    ./configure --prefix=/usr --host=$LFS_TGT
    make
    make DESTDIR=$LFS install
}

# 6.12 Make
make_pkg() {
    ./configure --prefix=/usr   \
                --host=$LFS_TGT \
                --build=$(build-aux/config.guess)
    make
    make DESTDIR=$LFS install
}

# 6.13 Patch
patch_pkg() {
    ./configure --prefix=/usr   \
                --host=$LFS_TGT \
                --build=$(build-aux/config.guess)
    make
    make DESTDIR=$LFS install
}

# 6.14 Sed
sed_pkg() {
    ./configure --prefix=/usr   \
                --host=$LFS_TGT \
                --build=$(./build-aux/config.guess)
    make
    make DESTDIR=$LFS install
}

# 6.15 Tar
tar_pkg() {
    ./configure --prefix=/usr   \
                --host=$LFS_TGT \
                --build=$(build-aux/config.guess)
    make
    make DESTDIR=$LFS install
}

# 6.16 Xz
xz_pkg() {
    ./configure --prefix=/usr                     \
                --host=$LFS_TGT                   \
                --build=$(build-aux/config.guess) \
                --disable-static                  \
                --docdir=/usr/share/doc/xz-$(pkg_version xz)
    make
    make DESTDIR=$LFS install
    rm -fv $LFS/usr/lib/liblzma.la
}

# 6.17 Binutils - Pass 2
binutils_pass2() {
    sed '6031s/$add_dir//' -i ltmain.sh

    mkdir -v build
    cd       build
    ../configure                   \
        --prefix=/usr              \
        --build=$(../config.guess) \
        --host=$LFS_TGT            \
        --disable-nls              \
        --enable-shared            \
        --enable-gprofng=no        \
        --disable-werror           \
        --enable-64-bit-bfd        \
        --enable-new-dtags         \
        --enable-default-hash-style=gnu
    make
    make DESTDIR=$LFS install
    rm -fv $LFS/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la}
}

# 6.18 GCC - Pass 2
gcc_pass2() {
    unpack_as mpfr mpfr
    unpack_as gmp  gmp
    unpack_as mpc  mpc

    case $(uname -m) in
      x86_64)
        sed -e '/m64=/s/lib64/lib/' \
            -i.orig gcc/config/i386/t-linux64
      ;;
    esac

    sed '/thread_header =/s/@.*@/gthr-posix.h/' \
        -i libgcc/Makefile.in libstdc++-v3/include/Makefile.in

    mkdir -v build
    cd       build
    ../configure                   \
        --build=$(../config.guess) \
        --host=$LFS_TGT            \
        --target=$LFS_TGT          \
        --prefix=/usr              \
        --with-build-sysroot=$LFS  \
        --enable-default-pie       \
        --enable-default-ssp       \
        --disable-nls              \
        --disable-multilib         \
        --disable-libatomic        \
        --disable-libgomp          \
        --disable-libquadmath      \
        --disable-libsanitizer     \
        --disable-libssp           \
        --disable-libvtv           \
        --enable-languages=c,c++   \
        LDFLAGS_FOR_TARGET=-L$PWD/$LFS_TGT/libgcc
    make
    make DESTDIR=$LFS install
    ln -sfv gcc $LFS/usr/bin/cc
}

build 06.2-m4             m4        m4_pkg
build 06.3-ncurses        ncurses   ncurses_pkg
build 06.4-bash           bash      bash_pkg
build 06.5-coreutils      coreutils coreutils_pkg
build 06.6-diffutils      diffutils diffutils_pkg
build 06.7-file           file      file_pkg
build 06.8-findutils      findutils findutils_pkg
build 06.9-gawk           gawk      gawk_pkg
build 06.10-grep          grep      grep_pkg
build 06.11-gzip          gzip      gzip_pkg
build 06.12-make          make      make_pkg
build 06.13-patch         patch     patch_pkg
build 06.14-sed           sed       sed_pkg
build 06.15-tar           tar       tar_pkg
build 06.16-xz            xz        xz_pkg
build 06.17-binutils-pass2 binutils binutils_pass2
build 06.18-gcc-pass2     gcc       gcc_pass2

echo "End of temp tools building"
