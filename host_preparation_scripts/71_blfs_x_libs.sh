#!/bin/bash
# BLFS 12.4 (sysv), lot X 1, DANS le chroot :
#   environnement Xorg, libpng, FreeType (passe 1), Fontconfig, util-macros, xorgproto,
#   libXau, libXdmcp, xcb-proto, libxcb, Xorg Libraries (32), libxcvt, XCB Utilities,
#   Pixman, libdrm, libyaml, Cython, PyYAML, Mako
#   Sur l'hôte :  ./70_get_blfs_sources.sh blfs/20_x_libs.list
#                 ./22_enter_chroot.sh 71_blfs_x_libs.sh
source "$(dirname "$0")/chroot_lib.sh"
chroot_init
need_stamp 70.11-ssh-user

# Introduction to Xorg-7 : préfixe standard /usr
export XORG_PREFIX="/usr"
export XORG_CONFIG="--prefix=$XORG_PREFIX --sysconfdir=/etc --localstatedir=/var --disable-static"

xorg_env() {
    # LFS ne crée pas /etc/profile.d (c'est BLFS, « Bash Shell Startup Files »)
    install -v -d -m755 /etc/profile.d
    # ... et le /etc/profile du chapitre 9 ne le lit pas : on l'ajoute une fois
    grep -q 'profile.d' /etc/profile || cat >> /etc/profile << "EOF"

# Scripts complémentaires (BLFS)
for script in /etc/profile.d/*.sh ; do
  if [ -r $script ] ; then
    . $script
  fi
done
unset script
EOF

    cat > /etc/profile.d/xorg.sh << EOF
XORG_PREFIX="$XORG_PREFIX"
XORG_CONFIG="--prefix=\$XORG_PREFIX --sysconfdir=/etc --localstatedir=/var --disable-static"
export XORG_PREFIX XORG_CONFIG
EOF
    chmod 644 /etc/profile.d/xorg.sh
}

# libpng
libpng_pkg() {
    ./configure --prefix=/usr --disable-static
    make
    t make check
    make install
    mkdir -pv /usr/share/doc/$P
    cp -v README libpng-manual.txt /usr/share/doc/$P
}

# FreeType (passe 1 ; repasse après HarfBuzz dans le lot Openbox)
freetype_pkg() {
    sed -ri "s:.*(AUX_MODULES.*valid):\1:" modules.cfg
    sed -r "s:.*(#.*SUBPIXEL_RENDERING) .*:\1:" \
        -i include/freetype/config/ftoption.h
    ./configure --prefix=/usr --enable-freetype-config --disable-static
    make
    make install
}

# Fontconfig
fontconfig_pkg() {
    ./configure --prefix=/usr        \
                --sysconfdir=/etc    \
                --localstatedir=/var \
                --disable-docs       \
                --docdir=/usr/share/doc/$P
    make
    t make check
    make install
}

# util-macros
util_macros_pkg() {
    ./configure $XORG_CONFIG
    make install
}

# xorgproto
xorgproto_pkg() {
    mkdir build
    cd    build
    meson setup --prefix=$XORG_PREFIX ..
    ninja
    ninja install
    rm -rf $XORG_PREFIX/share/doc/$P
    mv -v $XORG_PREFIX/share/doc/xorgproto{,-${P#xorgproto-}}
}

# libXau
libxau_pkg() {
    ./configure $XORG_CONFIG
    make
    t make check
    make install
}

# libXdmcp
libxdmcp_pkg() {
    ./configure $XORG_CONFIG --docdir=/usr/share/doc/$P
    make
    t make check
    make install
}

# xcb-proto
xcb_proto_pkg() {
    PYTHON=python3 ./configure $XORG_CONFIG
    make install
}

# libxcb
libxcb_pkg() {
    ./configure $XORG_CONFIG      \
                --without-doxygen \
                --docdir='${datadir}'/doc/$P
    LC_ALL=en_US.UTF-8 make
    t make check
    make install
}

# Xorg Libraries : la boucle du livre, une étape reprenable par bibliothèque
xorg_lib_pkg() {
    local docdir="--docdir=$XORG_PREFIX/share/doc/$P"
    case $P in
      libXfont2-[0-9]* )
        ./configure $XORG_CONFIG $docdir --disable-devel-docs ;;
      libXt-[0-9]* )
        ./configure $XORG_CONFIG $docdir \
                    --with-appdefaultdir=/etc/X11/app-defaults ;;
      libXpm-[0-9]* )
        ./configure $XORG_CONFIG $docdir --disable-open-zfile ;;
      libpciaccess* )
        mkdir build
        cd    build
        meson setup --prefix=$XORG_PREFIX --buildtype=release ..
        ninja
        ninja install
        /sbin/ldconfig
        return 0 ;;
      * )
        ./configure $XORG_CONFIG $docdir ;;
    esac
    make
    case $P in libX11-*|libXt-*|libXmu-*|libXpm-*|libxshmfence-*) t make check ;; esac
    make install
    /sbin/ldconfig
}
XORG_LIBS="xtrans libX11 libXext libFS libICE libSM libXScrnSaver libXt libXmu
           libXpm libXaw libXfixes libXcomposite libXrender libXcursor libXdamage
           libfontenc libXfont2 libXft libXi libXinerama libXrandr libXres libXtst
           libXv libXvMC libXxf86dga libXxf86vm libpciaccess libxkbfile libxshmfence
           libXpresent"

# libxcvt
libxcvt_pkg() {
    mkdir build
    cd    build
    meson setup --prefix=$XORG_PREFIX --buildtype=release ..
    ninja
    ninja install
}

# xcb-util et XCB Utilities (même recette)
xcb_util_pkg() {
    ./configure $XORG_CONFIG
    make
    make install
}
XCB_UTILS="xcb-util xcb-util-image xcb-util-keysyms xcb-util-renderutil xcb-util-wm xcb-util-cursor"

# Pixman
pixman_pkg() {
    mkdir build
    cd    build
    meson setup --prefix=/usr --buildtype=release ..
    ninja
    t ninja test
    ninja install
}

# libdrm
libdrm_pkg() {
    mkdir build
    cd    build
    meson setup --prefix=$XORG_PREFIX \
                --buildtype=release   \
                -D udev=true          \
                -D valgrind=disabled  \
                ..
    ninja
    t ninja test
    ninja install
}

# libyaml
libyaml_pkg() {
    ./configure --prefix=/usr --disable-static
    make
    t make check
    make install
}

# Modules Python (Cython, PyYAML, Mako) : recette commune de BLFS
pip_pkg() {
    pip3 wheel -w dist --no-build-isolation --no-deps --no-cache-dir $PWD
    pip3 install --no-index --find-links dist --no-user "$1"
}
cython_pkg() { pip_pkg Cython; }
pyyaml_pkg() { pip_pkg PyYAML; }
mako_pkg()   { pip_pkg Mako; }

step  71.00-xorg-env                         xorg_env
build 71.01-libpng        libpng             libpng_pkg
build 71.02-freetype      freetype           freetype_pkg
build 71.03-fontconfig    fontconfig         fontconfig_pkg
build 71.04-util-macros   util-macros        util_macros_pkg
build 71.05-xorgproto     xorgproto          xorgproto_pkg
build 71.06-libXau        libXau             libxau_pkg
build 71.07-libXdmcp      libXdmcp           libxdmcp_pkg
build 71.08-xcb-proto     xcb-proto          xcb_proto_pkg
build 71.09-libxcb        libxcb             libxcb_pkg
for l in $XORG_LIBS; do
    build "71.10-lib-$l"  "$l-[0-9]*.tar*"   xorg_lib_pkg
done
build 71.11-libxcvt       libxcvt            libxcvt_pkg
for u in $XCB_UTILS; do
    build "71.12-$u"      "$u-[0-9]*.tar*"   xcb_util_pkg
done
build 71.13-pixman        pixman             pixman_pkg
build 71.14-libdrm        libdrm             libdrm_pkg
build 71.15-libyaml       yaml               libyaml_pkg
build 71.16-cython        cython             cython_pkg
build 71.17-pyyaml        pyyaml             pyyaml_pkg
build 71.18-mako          mako               mako_pkg

echo
echo "Lot X 1 terminé. Suite : ./70_get_blfs_sources.sh blfs/30_x_server.list"
echo "                         ./22_enter_chroot.sh 72_blfs_x_server.sh"
