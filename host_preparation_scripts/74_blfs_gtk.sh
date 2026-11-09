#!/bin/bash
# BLFS 12.4 (sysv), palier 2, lot GTK, DANS le chroot :
#   D-Bus (+ bootscript), gsettings-desktop-schemas, at-spi2-core, shared-mime-info,
#   gdk-pixbuf, hicolor-icon-theme, ISO Codes, desktop-file-utils, startup-notification,
#   GTK 3, lxde-icon-theme, hwdata, libdisplay-info, libxklavier
#   Sur l'hôte :  ./70_get_blfs_sources.sh blfs/50_gtk.list
#                 ./22_enter_chroot.sh 74_blfs_gtk.sh
#
# Écarts volontaires par rapport au livre :
#  - pas de GObject Introspection (comme GLib au palier 1) : options désactivées
#    quand le paquet en a une ; inutile pour faire tourner Xfce
#  - gdk-pixbuf sans JPEG ni TIFF : libjpeg-turbo demande CMake et NASM
#  - GTK 3 sans backend Wayland (X11 seulement), sans démos ni tests
#  - icônes : lxde-icon-theme (PNG) au lieu d'adwaita-icon-theme, qui exige
#    librsvg, donc Rust. xfce4-settings accepte lxde-icon-theme (dépendance runtime).
source "$(dirname "$0")/chroot_lib.sh"
chroot_init
need_stamp 73.10-openbox-session

# D-Bus
dbus_pkg() {
    mkdir build
    cd    build
    meson setup --prefix=/usr          \
                --buildtype=release    \
                --wrap-mode=nofallback \
                -D systemd=disabled    \
                ..
    ninja
    ninja install

    chown -v root:messagebus /usr/libexec/dbus-daemon-launch-helper
    chmod -v      4750       /usr/libexec/dbus-daemon-launch-helper
    dbus-uuidgen --ensure

    if [ -e /usr/share/doc/dbus ]; then
        rm -rf /usr/share/doc/$P
        mv -v  /usr/share/doc/dbus /usr/share/doc/$P
    fi

    cat > /etc/dbus-1/session-local.conf << "EOF"
<!DOCTYPE busconfig PUBLIC
 "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>

  <!-- Search for .service files in /usr/local -->
  <servicedir>/usr/local/share/dbus-1/services</servicedir>

</busconfig>
EOF
}

# Bootscript dbus (bus système au démarrage)
dbus_bootscript() {
    make install-dbus
    ls -l /etc/rc.d/rc3.d/ | grep dbus
}

# gsettings-desktop-schemas
gsettings_schemas_pkg() {
    sed -i -r 's:"(/system):"/org/gnome\1:g' schemas/*.in
    mkdir build
    cd    build
    meson setup --prefix=/usr --buildtype=release -D introspection=false ..
    ninja
    ninja install
}

# at-spi2-core
at_spi2_core_pkg() {
    mkdir build
    cd    build
    meson setup ..                  \
          --prefix=/usr             \
          --buildtype=release       \
          -D gtk2_atk_adaptor=false \
          -D introspection=disabled \
          -D systemd_user_dir=/tmp
    ninja
    ninja install
    rm -f /tmp/at-spi-dbus-bus.service
}

# shared-mime-info
shared_mime_info_pkg() {
    mkdir build
    cd    build
    meson setup --prefix=/usr --buildtype=release -D update-mimedb=true ..
    ninja
    ninja install
}

# gdk-pixbuf
gdk_pixbuf_pkg() {
    mkdir build
    cd    build
    meson setup ..                  \
          --prefix=/usr             \
          --buildtype=release       \
          -D others=enabled         \
          -D jpeg=disabled          \
          -D tiff=disabled          \
          -D man=false              \
          -D introspection=disabled \
          --wrap-mode=nofallback
    ninja
    t ninja test
    ninja install
    gdk-pixbuf-query-loaders --update-cache
}

# hicolor-icon-theme
hicolor_pkg() {
    mkdir build
    cd    build
    meson setup --prefix=/usr --buildtype=release ..
    ninja
    ninja install
}

# ISO Codes
iso_codes_pkg() {
    ./configure --prefix=/usr
    make
    make install LN_S='ln -sfn'
}

# desktop-file-utils
desktop_file_utils_pkg() {
    rm -fv /usr/bin/desktop-file-edit
    mkdir build
    cd    build
    meson setup --prefix=/usr --buildtype=release ..
    ninja
    ninja install
    install -vdm755 /usr/share/applications
    update-desktop-database /usr/share/applications
}

# startup-notification
startup_notification_pkg() {
    ./configure --prefix=/usr --disable-static
    make
    make install
    install -v -m644 -D doc/startup-notification.txt \
        /usr/share/doc/$P/startup-notification.txt
}

# GTK 3
gtk3_pkg() {
    mkdir build
    cd    build
    meson setup ..                 \
          --prefix=/usr            \
          --buildtype=release      \
          -D x11_backend=true      \
          -D wayland_backend=false \
          -D introspection=false   \
          -D demos=false           \
          -D examples=false        \
          -D tests=false
    ninja
    ninja install
    gtk-query-immodules-3.0 --update-cache
    glib-compile-schemas /usr/share/glib-2.0/schemas
}

# lxde-icon-theme (thème d'icônes PNG nuoveXT2)
lxde_icons_pkg() {
    ./configure --prefix=/usr
    make install
    gtk-update-icon-cache -qf /usr/share/icons/nuoveXT2
    gtk-update-icon-cache -qf /usr/share/icons/hicolor
}

# hwdata
hwdata_pkg() {
    ./configure --prefix=/usr --disable-blacklist
    make install
}

# libdisplay-info
libdisplay_info_pkg() {
    mkdir build
    cd    build
    meson setup --prefix=/usr --buildtype=release ..
    ninja
    ninja install
}

# libxklavier
libxklavier_pkg() {
    ./configure --prefix=/usr --disable-static --disable-introspection --disable-vala
    make
    make install
}

build 74.01-dbus                 dbus                  dbus_pkg
build 74.02-dbus-bootscript      blfs-bootscripts      dbus_bootscript
build 74.03-gsettings-schemas    gsettings-desktop-schemas gsettings_schemas_pkg
build 74.04-at-spi2-core         at-spi2-core          at_spi2_core_pkg
build 74.05-shared-mime-info     shared-mime-info      shared_mime_info_pkg
build 74.06-gdk-pixbuf           gdk-pixbuf            gdk_pixbuf_pkg
build 74.07-hicolor-icon-theme   hicolor-icon-theme    hicolor_pkg
build 74.08-iso-codes            'iso-codes-v*.tar.gz' iso_codes_pkg
build 74.09-desktop-file-utils   desktop-file-utils    desktop_file_utils_pkg
build 74.10-startup-notification startup-notification startup_notification_pkg
build 74.11-gtk3                 gtk                   gtk3_pkg
build 74.12-lxde-icon-theme      lxde-icon-theme       lxde_icons_pkg
build 74.13-hwdata               hwdata                hwdata_pkg
build 74.14-libdisplay-info      libdisplay-info       libdisplay_info_pkg
build 74.15-libxklavier          libxklavier           libxklavier_pkg

echo
echo "Lot GTK terminé. Suite : ./70_get_blfs_sources.sh blfs/60_xfce.list"
echo "                         ./22_enter_chroot.sh 75_blfs_xfce.sh"
