#!/bin/bash
# BLFS 12.4 (sysv), lot X 2, DANS le chroot :
#   Mesa (sans LLVM : svga + softpipe), libepoxy, xbitmaps, Xorg Applications (33),
#   xcursor-themes, Xorg Fonts (9), XKeyboardConfig, Xorg-Server, mtdev, libevdev,
#   pilotes evdev/libinput, twm, xterm, xclock, xinit, configuration
#   Sur l'hôte :  ./70_get_blfs_sources.sh blfs/30_x_server.list
#                 ./22_enter_chroot.sh 72_blfs_x_server.sh
#
# Écarts volontaires par rapport au livre (choix du palier 1, VM VirtualBox) :
#  - Mesa : gallium-drivers=svga,softpipe, pas de Vulkan, pas de Wayland, pas de LLVM
#    (llvmpipe, radeonsi... exigent LLVM ; svga = VMSVGA de VirtualBox/VMware)
#  - Xorg-Server sans elogind : systemd_logind=false + suid_wrapper=true et
#    /etc/X11/Xwrapper.config (needs_root_rights) pour que startx marche hors root.
#    BLFS recommande elogind ; ce wrapper est la solution classique sans lui.
#  - secure-rpc=false : libtirpc n'est pas installé
source "$(dirname "$0")/chroot_lib.sh"
chroot_init
need_stamp 71.18-mako

set -a
source "$(dirname "$0")/ft_config.sh"
set +a
export XKB_LAYOUT="${XKB_LAYOUT:-fr}"
export XORG_PREFIX="/usr"
export XORG_CONFIG="--prefix=$XORG_PREFIX --sysconfdir=/etc --localstatedir=/var --disable-static"

# Mesa
mesa_pkg() {
    mkdir build
    cd    build
    meson setup ..                         \
          --prefix=$XORG_PREFIX            \
          --buildtype=release              \
          -D platforms=x11                 \
          -D gallium-drivers=svga,softpipe \
          -D vulkan-drivers=               \
          -D llvm=disabled                 \
          -D valgrind=disabled             \
          -D libunwind=disabled
    ninja
    ninja install
    cp -rv ../docs -T /usr/share/doc/$P
}

# libepoxy
libepoxy_pkg() {
    mkdir build
    cd    build
    meson setup --prefix=/usr --buildtype=release ..
    ninja
    t ninja test
    ninja install
}

# xbitmaps
xbitmaps_pkg() {
    ./configure $XORG_CONFIG
    make install
}

# Xorg Applications, Xorg Fonts : même recette (boucle du livre)
xorg_simple_pkg() {
    ./configure $XORG_CONFIG
    make
    make install
}
XORG_APPS="iceauth mkfontscale sessreg setxkbmap smproxy xauth xcmsdb xcursorgen
           xdpyinfo xdriinfo xev xgamma xhost xinput xkbcomp xkbevd xkbutils xkill
           xlsatoms xlsclients xmessage xmodmap xpr xprop xrandr xrdb xrefresh xset
           xsetroot xvinfo xwd xwininfo xwud"
XORG_FONTS="font-util encodings font-alias font-adobe-utopia-type1 font-bh-ttf
            font-bh-type1 font-ibm-type1 font-misc-ethiopic font-xfree86-type1"

xorg_apps_post() {
    rm -f $XORG_PREFIX/bin/xkeystone
}

# xcursor-themes
xcursor_themes_pkg() {
    ./configure --prefix=/usr
    make
    make install
}

# XKeyboardConfig
xkeyboard_config_pkg() {
    mkdir build
    cd    build
    meson setup --prefix=$XORG_PREFIX --buildtype=release ..
    ninja
    t ninja test
    ninja install
}

# Xorg-Server
xorg_server_pkg() {
    mkdir build
    cd    build
    meson setup ..               \
          --prefix=$XORG_PREFIX  \
          --localstatedir=/var   \
          -D glamor=true         \
          -D systemd_logind=false \
          -D suid_wrapper=true   \
          -D secure-rpc=false    \
          -D xkb_output_dir=/var/lib/xkb
    ninja
    ldconfig
    t ninja test
    ninja install
    mkdir -pv /etc/X11/xorg.conf.d
    install -v -d -m1777 /tmp/.{ICE,X11}-unix
    grep -q '^/tmp/.X11-unix' /etc/sysconfig/createfiles || cat >> /etc/sysconfig/createfiles << "EOF"
/tmp/.ICE-unix dir 1777 root root
/tmp/.X11-unix dir 1777 root root
EOF
}

# mtdev
mtdev_pkg() {
    ./configure --prefix=/usr --disable-static
    make
    make install
}

# libevdev
libevdev_pkg() {
    mkdir build
    cd    build
    meson setup ..                  \
          --prefix=$XORG_PREFIX     \
          --buildtype=release       \
          -D documentation=disabled \
          -D tests=disabled
    ninja
    ninja install
}

# Xorg Evdev Driver
xf86_evdev_pkg() {
    ./configure $XORG_CONFIG
    make
    make install
}

# libinput
libinput_pkg() {
    mkdir build
    cd    build
    meson setup ..              \
          --prefix=$XORG_PREFIX \
          --buildtype=release   \
          -D debug-gui=false    \
          -D tests=false        \
          -D libwacom=false     \
          -D udev-dir=/usr/lib/udev
    ninja
    ninja install
}

# Xorg Libinput Driver
xf86_libinput_pkg() {
    ./configure $XORG_CONFIG
    make
    t make check
    make install
}

# twm
twm_pkg() {
    sed -i -e '/^rcdir =/s,^\(rcdir = \).*,\1/etc/X11/app-defaults,' src/Makefile.in
    ./configure $XORG_CONFIG
    make
    make install
}

# xterm
xterm_pkg() {
    sed -i '/v0/{n;s/new:/new:kb=^?:/}' termcap
    printf '\tkbs=\\177,\n' >> terminfo
    TERMINFO=/usr/share/terminfo \
    ./configure $XORG_CONFIG     \
                --with-app-defaults=/etc/X11/app-defaults
    make
    make install
    mkdir -pv /usr/share/applications
    cp -v *.desktop /usr/share/applications/

    grep -q 'faceName: Monospace' /etc/X11/app-defaults/XTerm || \
    cat >> /etc/X11/app-defaults/XTerm << "EOF"
*VT100*locale: true
*VT100*faceName: Monospace
*VT100*faceSize: 10
*backarrowKeyIsErase: true
*ptyInitialErase: true
EOF
}

# xclock
xclock_pkg() {
    ./configure $XORG_CONFIG
    make
    make install
}

# xinit
xinit_pkg() {
    ./configure $XORG_CONFIG --with-xinitdir=/etc/X11/app-defaults
    make
    make install
    ldconfig
}

# Xorg-7 Testing and Configuration + wrapper sans elogind
x_config() {
    ldconfig

    cat > /etc/X11/xorg.conf.d/xkb-defaults.conf << EOF
Section "InputClass"
    Identifier "XKB Defaults"
    MatchIsKeyboard "yes"
    Option "XkbLayout" "$XKB_LAYOUT"
    Option "XkbOptions" "terminate:ctrl_alt_bksp"
EndSection
EOF

    # Sans elogind, le serveur doit tourner avec les droits root (voir en tête)
    cat > /etc/X11/Xwrapper.config << "EOF"
# startx depuis une console locale : Xorg.wrap lance le serveur en root
allowed_users=console
needs_root_rights=yes
EOF
    ls -l /usr/libexec/Xorg.wrap 2>/dev/null || ls -l /usr/lib*/xorg/Xorg.wrap 2>/dev/null || true
}

build 72.01-mesa            mesa              mesa_pkg
build 72.02-libepoxy        libepoxy          libepoxy_pkg
build 72.03-xbitmaps        xbitmaps          xbitmaps_pkg
for a in $XORG_APPS; do
    build "72.04-app-$a"    "$a-[0-9]*.tar*"  xorg_simple_pkg
done
step  72.05-apps-post                         xorg_apps_post
build 72.06-xcursor-themes  xcursor-themes    xcursor_themes_pkg
for f in $XORG_FONTS; do
    build "72.07-font-$f"   "$f-[0-9]*.tar*"  xorg_simple_pkg
done
build 72.08-xkeyboard-config xkeyboard-config xkeyboard_config_pkg
build 72.09-xorg-server     xorg-server       xorg_server_pkg
build 72.10-mtdev           mtdev             mtdev_pkg
build 72.11-libevdev        libevdev          libevdev_pkg
build 72.12-xf86-input-evdev xf86-input-evdev xf86_evdev_pkg
build 72.13-libinput        libinput          libinput_pkg
build 72.14-xf86-input-libinput xf86-input-libinput xf86_libinput_pkg
build 72.15-twm             twm               twm_pkg
build 72.16-xterm           'xterm-*.tgz'     xterm_pkg
build 72.17-xclock          xclock            xclock_pkg
build 72.18-xinit           xinit             xinit_pkg
step  72.19-x-config                          x_config

echo
echo "Lot X 2 terminé : Xorg + twm. Test possible dans la VM :  startx"
echo "Suite : ./70_get_blfs_sources.sh blfs/40_openbox.list"
echo "        ./22_enter_chroot.sh 73_blfs_openbox.sh"
