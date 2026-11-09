#!/bin/bash
# BLFS 12.4 (sysv), lot X 3, DANS le chroot :
#   PCRE2, GLib, FriBidi, HarfBuzz, FreeType (passe 2), Cairo, Pango, libxml2, DejaVu, Openbox
#   Sur l'hôte :  ./70_get_blfs_sources.sh blfs/40_openbox.list
#                 ./22_enter_chroot.sh 73_blfs_openbox.sh
#
# Écarts : GLib et Pango sans GObject Introspection (inutile pour Openbox),
# GLib sans pages man (docutils/libxslt absents), HarfBuzz sans Graphite2.
source "$(dirname "$0")/chroot_lib.sh"
chroot_init
need_stamp 72.19-x-config

set -a
source "$(dirname "$0")/ft_config.sh"
set +a
export SSH_USER="${SSH_USER:-$LFS_HOSTNAME}"

# PCRE2 (recommandé par GLib ; sinon GLib le télécharge pendant le build)
pcre2_pkg() {
    ./configure --prefix=/usr                   \
                --docdir=/usr/share/doc/$P      \
                --enable-unicode                \
                --enable-jit                    \
                --enable-pcre2-16               \
                --enable-pcre2-32               \
                --enable-pcre2grep-libz         \
                --enable-pcre2grep-libbz2       \
                --enable-pcre2test-libreadline  \
                --disable-static
    make
    t make check
    make install
}

# GLib (sans introspection)
glib_pkg() {
    if [ -e /usr/include/glib-2.0 ]; then
        rm -rf /usr/include/glib-2.0.old
        mv -vf /usr/include/glib-2.0{,.old}
    fi
    mkdir build
    cd    build
    meson setup ..                  \
          --prefix=/usr             \
          --buildtype=release       \
          -D introspection=disabled \
          -D glib_debug=disabled    \
          -D man-pages=disabled     \
          -D sysprof=disabled
    ninja
    ninja install
}

# FriBidi
fribidi_pkg() {
    mkdir build
    cd    build
    meson setup --prefix=/usr --buildtype=release ..
    ninja
    t ninja test
    ninja install
}

# HarfBuzz
harfbuzz_pkg() {
    mkdir build
    cd    build
    meson setup ..             \
          --prefix=/usr        \
          --buildtype=release  \
          -D graphite2=disabled
    ninja
    t ninja test
    ninja install
}

# FreeType, passe 2 : avec HarfBuzz (dépendance circulaire du livre)
freetype_pkg() {
    sed -ri "s:.*(AUX_MODULES.*valid):\1:" modules.cfg
    sed -r "s:.*(#.*SUBPIXEL_RENDERING) .*:\1:" \
        -i include/freetype/config/ftoption.h
    ./configure --prefix=/usr --enable-freetype-config --disable-static
    make
    make install
}

# Cairo
cairo_pkg() {
    mkdir build
    cd    build
    meson setup --prefix=/usr --buildtype=release ..
    ninja
    ninja install
}

# Pango (avec libXft, sans introspection)
pango_pkg() {
    mkdir build
    cd    build
    meson setup --prefix=/usr             \
                --buildtype=release       \
                --wrap-mode=nofallback    \
                -D introspection=disabled \
                ..
    ninja
    ninja install
}

# libxml2 (requis par Openbox ; sans ICU, recommandé mais non installé)
libxml2_pkg() {
    ./configure --prefix=/usr     \
                --sysconfdir=/etc \
                --disable-static  \
                --with-history    \
                PYTHON=/usr/bin/python3 \
                --docdir=/usr/share/doc/$P
    make
    make install
    rm -vf /usr/lib/libxml2.la
    sed '/libs=/s/xml2.*/xml2"/' -i /usr/bin/xml2-config
}

# DejaVu (TTF and OTF fonts)
dejavu_pkg() {
    install -v -d -m755 /usr/share/fonts/dejavu
    install -v -m644 ttf/*.ttf /usr/share/fonts/dejavu
    fc-cache -v /usr/share/fonts/dejavu
}

# Openbox
openbox_pkg() {
    patch -Np1 -i "$(find_file 'openbox-*-py3-1.patch')"
    autoreconf -fi
    ./configure --prefix=/usr     \
                --sysconfdir=/etc \
                --disable-static  \
                --docdir=/usr/share/doc/$P
    make
    make install
    rm -fv /usr/share/xsessions/openbox-{gnome,kde}.desktop
}

# Session : startx lance Openbox, pour root et l'utilisateur SSH
openbox_session() {
    # Le menu par défaut d'Openbox appelle x-terminal-emulator
    ln -sfv xterm /usr/bin/x-terminal-emulator

    local home
    for home in /root $(getent passwd "$SSH_USER" | cut -d: -f6); do
        [ -d "$home" ] || continue
        cat > "$home/.xinitrc" << "EOF"
. /etc/profile
xsetroot -solid '#2e3440'
exec openbox-session
EOF
        mkdir -p "$home/.config"
        cp -rf /etc/xdg/openbox "$home/.config/"
        cat > "$home/.config/openbox/autostart" << "EOF"
xterm &
EOF
        local owner; owner=$(stat -c %U "$home")
        chown -R "$owner:" "$home/.xinitrc" "$home/.config"
    done
}

# startx au démarrage : après connexion sur tty1, et connexion automatique en option
x_autostart() {
    local home
    for home in /root $(getent passwd "$SSH_USER" | cut -d: -f6); do
        [ -d "$home" ] || continue
        local bp="$home/.bash_profile"
        touch "$bp"
        # Bloc remplacé à chaque passage (étape relançable)
        sed -i '/^# >>> ft_linux startx/,/^# <<< ft_linux startx/d' "$bp"
        if [ "${X_AUTOSTART:-1}" = 1 ]; then
            cat >> "$bp" << "EOF"
# >>> ft_linux startx
# Session graphique automatique sur la première console uniquement.
# Pas de « exec » : si X échoue, on garde un shell au lieu de boucler.
if [ -z "$DISPLAY" ] && [ "$(tty)" = /dev/tty1 ]; then
    startx
fi
# <<< ft_linux startx
EOF
        fi
        chown "$(stat -c %U "$home"):" "$bp"
    done

    # Connexion automatique sur tty1 (agetty --autologin)
    if [ -n "${AUTOLOGIN_USER:-}" ]; then
        id "$AUTOLOGIN_USER" >/dev/null || { echo "utilisateur $AUTOLOGIN_USER inconnu"; exit 1; }
        sed -i "s|^1:2345:respawn:/sbin/agetty .*tty1 9600|1:2345:respawn:/sbin/agetty --noclear --autologin $AUTOLOGIN_USER tty1 9600|" /etc/inittab
    else
        sed -i "s|^1:2345:respawn:/sbin/agetty .*tty1 9600|1:2345:respawn:/sbin/agetty --noclear tty1 9600|" /etc/inittab
    fi
    grep '^1:' /etc/inittab
}

build 73.01-pcre2         pcre2               pcre2_pkg
build 73.02-glib          glib                glib_pkg
build 73.03-fribidi       fribidi             fribidi_pkg
build 73.04-harfbuzz      harfbuzz            harfbuzz_pkg
build 73.05-freetype-2    freetype            freetype_pkg
build 73.06-cairo         cairo               cairo_pkg
build 73.07-pango         pango               pango_pkg
build 73.08a-libxml2      libxml2             libxml2_pkg
build 73.08-dejavu        dejavu-fonts-ttf    dejavu_pkg
build 73.09-openbox       openbox             openbox_pkg
step  73.10-openbox-session                   openbox_session
rm -f "$STAMPS/73.11-x-autostart"     # toujours réappliqué : suit ft_config.sh
step  73.11-x-autostart                       x_autostart

echo
echo "Palier 1 terminé : Xorg + Openbox."
echo "Dans la VM (console, pas SSH) :  startx"
echo "Clic droit sur le bureau = menu Openbox (Terminal, Reconfigure, Exit)."
