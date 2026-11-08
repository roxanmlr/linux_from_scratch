#!/usr/bin/env bash

source "$(dirname "$(realpath "$0")")/build_lib.sh"
ft_linux_init "$@"


GCC_VER="$(pkg_version gcc)"
GLIBC_VER="$(pkg_version glibc)"
export GCC_VER GLIBC_VER
echo "GCC $GCC_VER, Glibc $GLIBC_VER"
 
# 5.2 Binutils - Pass 1
binutils_pass1() {
    mkdir -v build
    cd       build
    ../configure --prefix=$LFS/tools \
                 --with-sysroot=$LFS \
                 --target=$LFS_TGT   \
                 --disable-nls       \
                 --enable-gprofng=no \
                 --disable-werror    \
                 --enable-new-dtags  \
                 --enable-default-hash-style=gnu
    make
    make install
}

# 5.3 GCC - Pass 1
gcc_pass1() {
    unpack_as mpfr mpfr
    unpack_as gmp  gmp
    unpack_as mpc  mpc

    case $(uname -m) in
      x86_64)
        sed -e '/m64=/s/lib64/lib/' \
            -i.orig gcc/config/i386/t-linux64
     ;;
    esac

    mkdir -v build
    cd       build
    ../configure                  \
        --target=$LFS_TGT         \
        --prefix=$LFS/tools       \
        --with-glibc-version=$GLIBC_VER \
        --with-sysroot=$LFS       \
        --with-newlib             \
        --without-headers         \
        --enable-default-pie      \
        --enable-default-ssp      \
        --disable-nls             \
        --disable-shared          \
        --disable-multilib        \
        --disable-threads         \
        --disable-libatomic       \
        --disable-libgomp         \
        --disable-libquadmath     \
        --disable-libssp          \
        --disable-libvtv          \
        --disable-libstdcxx       \
        --enable-languages=c,c++
    make
    make install

    cd ..
    cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
      "$(dirname "$($LFS_TGT-gcc -print-libgcc-file-name)")/include/limits.h"
}

# 5.4 Linux API Headers
linux_headers() {
    make mrproper
    make headers
    find usr/include -type f ! -name '*.h' -delete
    cp -rv usr/include $LFS/usr
}

# Vérifications de fin de 5.5, transformées en tests bloquants
glibc_sanity() {
    echo 'int main(){}' | $LFS_TGT-gcc -x c - -v -Wl,--verbose &> dummy.log

    local interp
    interp="$(readelf -l a.out | grep ': /lib' || true)"
    echo "interpréteur : $interp"
    [[ $interp == *"program interpreter: /lib"* ]] || { echo "SANITY: interpréteur incorrect"; return 1; }
    [[ $interp != *"$LFS"* ]]                     || { echo "SANITY: l'interpréteur contient $LFS"; return 1; }

    local crt
    crt="$(grep -E -o "$LFS/lib.*/S?crt[1in].*succeeded" dummy.log || true)"
    echo "$crt"
    [ "$(grep -c succeeded <<<"$crt")" -eq 3 ]    || { echo "SANITY: fichiers crt incorrects"; return 1; }

    grep -B3 "^ $LFS/usr/include" dummy.log      || { echo "SANITY: chemin des en-têtes incorrect"; return 1; }

    grep 'SEARCH.*/usr/lib' dummy.log | sed 's|; |\n|g' || true

    grep "/lib.*/libc.so.6 " dummy.log || true
    grep -q "attempt to open $LFS/usr/lib/libc.so.6 succeeded" dummy.log \
                                                  || { echo "SANITY: mauvaise libc"; return 1; }

    grep found dummy.log || true
    grep -q "found ld-.* at $LFS/usr/lib/ld-" dummy.log \
                                                  || { echo "SANITY: mauvais chargeur dynamique"; return 1; }

    rm -v a.out dummy.log
}

# 5.5 Glibc
glibc_pkg() {
    case $(uname -m) in
        i?86)   ln -sfv ld-linux.so.2 $LFS/lib/ld-lsb.so.3
        ;;
        x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64
                ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3
        ;;
    esac

    patch -Np1 -i "$SRC/glibc-$GLIBC_VER-fhs-1.patch"

    mkdir -v build
    cd       build
    echo "rootsbindir=/usr/sbin" > configparms

    ../configure                             \
          --prefix=/usr                      \
          --host=$LFS_TGT                    \
          --build=$(../scripts/config.guess) \
          --disable-nscd                     \
          libc_cv_slibdir=/usr/lib           \
          --enable-kernel=5.4

    # Le livre signale des échecs possibles en parallèle : repli en -j1
    make || make -j1
    make DESTDIR=$LFS install

    sed '/RTLDLIST=/s@/usr@@g' -i $LFS/usr/bin/ldd

    glibc_sanity
}

# 5.6 Libstdc++ (sources de GCC)
libstdcxx() {
    mkdir -v build
    cd       build
    ../libstdc++-v3/configure      \
        --host=$LFS_TGT            \
        --build=$(../config.guess) \
        --prefix=/usr              \
        --disable-multilib         \
        --disable-nls              \
        --disable-libstdcxx-pch    \
        --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/$GCC_VER
    make
    make DESTDIR=$LFS install
    rm -fv $LFS/usr/lib/lib{stdc++{,exp,fs},supc++}.la
}

build 05.2-binutils-pass1 binutils binutils_pass1
build 05.3-gcc-pass1      gcc      gcc_pass1
build 05.4-linux-headers  linux    linux_headers
build 05.5-glibc          glibc    glibc_pkg
build 05.6-libstdcxx      gcc      libstdcxx


echo "End of cross_toolchain, then launch 11_temp_tools.sh"
