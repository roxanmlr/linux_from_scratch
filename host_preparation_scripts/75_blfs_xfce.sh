#!/bin/bash
# BLFS 12.4 (sysv), palier 2, lot Xfce 4.20, DANS le chroot (chapitre « Xfce Desktop ») :
#   libxfce4util, Xfconf, libxfce4ui, Exo, Garcon, libwnck, xfce4-dev-tools,
#   libxfce4windowing, xfce4-panel, Thunar, Tumbler, xfce4-appfinder,
#   xfce4-settings, Xfdesktop, Xfwm4, xfce4-session, puis configuration
#   Sur l'hôte :  ./70_get_blfs_sources.sh blfs/60_xfce.list
#                 ./22_enter_chroot.sh 75_blfs_xfce.sh
#
# Non construits : thunar-volman (libgudev, montage automatique) et
# xfce4-power-manager (UPower, polkit) : utiles sur un portable, pas dans une VM.
# Les scripts configure d'Xfce détectent l'absence de GObject Introspection et de Vala.
source "$(dirname "$0")/chroot_lib.sh"
chroot_init
need_stamp 74.15-libxklavier

set -a
source "$(dirname "$0")/ft_config.sh"
set +a
export SSH_USER="${SSH_USER:-$LFS_HOSTNAME}"
export X_SESSION="${X_SESSION:-xfce}"
export ICON_THEME="${ICON_THEME:-nuoveXT2}"

# Recette commune : configure (avec options), make, make install
xfce_pkg() {   # xfce_pkg <options configure...>
    ./configure --prefix=/usr "$@"
    make
    make install
}

libxfce4util_pkg()      { xfce_pkg; }
xfconf_pkg()            { xfce_pkg; }
libxfce4ui_pkg()        { xfce_pkg --sysconfdir=/etc; }
exo_pkg()               { xfce_pkg --sysconfdir=/etc; }
garcon_pkg()            { xfce_pkg --sysconfdir=/etc; }
xfce4_dev_tools_pkg()   { xfce_pkg; }
xfce4_panel_pkg()       { xfce_pkg --sysconfdir=/etc; }
xfce4_appfinder_pkg()   { xfce_pkg; }
xfce4_settings_pkg()    { xfce_pkg --sysconfdir=/etc; }
xfdesktop_pkg()         { xfce_pkg; }
xfwm4_pkg()             { xfce_pkg; }

# libwnck (meson)
libwnck_pkg() {
    mkdir build
    cd    build
    meson setup --prefix=/usr --buildtype=release -D introspection=disabled ..
    ninja
    ninja install
}

# libxslt (xsltproc, exigé par le configure de xfce4-dev-tools)
libxslt_pkg() {
    ./configure --prefix=/usr    \
                --disable-static \
                --docdir=/usr/share/doc/$P
    make
    t make check
    make install
}

# libxfce4windowing
libxfce4windowing_pkg() {
    xfce_pkg --sysconfdir=/etc --enable-x11 --disable-debug
}

# Thunar
thunar_pkg() {
    sed -i 's/\tinstall-systemd_userDATA/\t/' Makefile.in
    xfce_pkg --sysconfdir=/etc --docdir=/usr/share/doc/$P
}

# Tumbler
tumbler_pkg() {
    xfce_pkg --sysconfdir=/etc
    rm -fv /usr/lib/systemd/user/tumblerd.service
}

# xfce4-session
xfce4_session_pkg() {
    xfce_pkg --sysconfdir=/etc --disable-legacy-sm
    update-desktop-database
    update-mime-database /usr/share/mime
}

# Configuration système : thème d'icônes par défaut, caches
xfce_config() {
    # Le thème par défaut d'xfce4-settings (Rodent / Adwaita) n'est pas installé
    local xs=/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml
    if [ -f "$xs" ]; then
        sed -i "s|\(name=\"IconThemeName\" type=\"string\" value=\"\)[^\"]*|\1$ICON_THEME|" "$xs"
        grep IconThemeName "$xs"
    fi
    install -vdm755 /etc/gtk-3.0
    cat > /etc/gtk-3.0/settings.ini << EOF
[Settings]
gtk-icon-theme-name = $ICON_THEME
gtk-font-name = DejaVu Sans 10
EOF
    glib-compile-schemas /usr/share/glib-2.0/schemas
    gtk-update-icon-cache -qf /usr/share/icons/hicolor
    update-desktop-database /usr/share/applications
}

# ~/.xinitrc selon X_SESSION (xfce ou openbox) ; toujours réappliqué
x_session() {
    local home owner
    for home in /root $(getent passwd "$SSH_USER" | cut -d: -f6); do
        [ -d "$home" ] || continue
        case "$X_SESSION" in
          xfce)
            cat > "$home/.xinitrc" << "EOF"
. /etc/profile
# D-Bus de session indispensable à Xfce (BLFS, xfce4-session)
exec dbus-launch --exit-with-x11 startxfce4
EOF
            ;;
          openbox)
            cat > "$home/.xinitrc" << "EOF"
. /etc/profile
xsetroot -solid '#2e3440'
exec openbox-session
EOF
            ;;
          *) echo "X_SESSION inconnu : $X_SESSION (xfce ou openbox)"; exit 1 ;;
        esac
        owner=$(stat -c %U "$home")
        chown "$owner:" "$home/.xinitrc"
        echo "$home/.xinitrc -> $X_SESSION"
    done
}

build 75.01-libxfce4util      libxfce4util      libxfce4util_pkg
build 75.02-xfconf            xfconf            xfconf_pkg
build 75.03-libxfce4ui        libxfce4ui        libxfce4ui_pkg
build 75.04-exo               exo               exo_pkg
build 75.05-garcon            garcon            garcon_pkg
build 75.06-libwnck           libwnck           libwnck_pkg
build 75.06b-libxslt         libxslt           libxslt_pkg
build 75.07-xfce4-dev-tools   xfce4-dev-tools   xfce4_dev_tools_pkg
build 75.08-libxfce4windowing libxfce4windowing libxfce4windowing_pkg
build 75.09-xfce4-panel       xfce4-panel       xfce4_panel_pkg
build 75.10-thunar            thunar            thunar_pkg
build 75.11-tumbler           tumbler           tumbler_pkg
build 75.12-xfce4-appfinder   xfce4-appfinder   xfce4_appfinder_pkg
build 75.13-xfce4-settings    xfce4-settings    xfce4_settings_pkg
build 75.14-xfdesktop         xfdesktop         xfdesktop_pkg
build 75.15-xfwm4             xfwm4             xfwm4_pkg
build 75.16-xfce4-session     xfce4-session     xfce4_session_pkg
step  75.17-xfce-config                         xfce_config
rm -f "$STAMPS/75.18-x-session"      # toujours réappliqué : suit ft_config.sh
step  75.18-x-session                           x_session

echo
echo "Palier 2 terminé : Xfce 4.20 (session : $X_SESSION)."
echo "Dans la VM : connexion sur tty1 (startx automatique si X_AUTOSTART=1), ou startx."
echo "Messages de session : startx &> ~/.x-session-errors"
