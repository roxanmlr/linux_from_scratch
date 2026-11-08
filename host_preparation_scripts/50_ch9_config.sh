#!/bin/bash
# LFS 12.4 - Chapitre 9 : configuration du système (SysVinit), DANS le chroot
#   Sur l'hôte :  ./22_enter_chroot.sh 50_ch9_config.sh
#   Valeurs    :  chroot/ft_config.sh
# 9.3 et 9.4 sont des explications : on n'y crée pas de règles réseau persistantes,
# l'interface s'appellera eth0 grâce à net.ifnames=0 (posé dans grub.cfg, chapitre 10).
source "$(dirname "$0")/chroot_lib.sh"
chroot_init
need_stamp 08.85-cleanup

set -a
source "$(dirname "$0")/ft_config.sh"
set +a

# 9.2 LFS-Bootscripts
bootscripts_pkg() {
    make install
}

# 9.5 General Network Configuration
network() {
    cat > /etc/sysconfig/ifconfig.$NET_IFACE << EOF
ONBOOT=yes
IFACE=$NET_IFACE
SERVICE=ipv4-static
IP=$NET_IP
GATEWAY=$NET_GATEWAY
PREFIX=$NET_PREFIX
BROADCAST=$NET_BROADCAST
EOF

    cat > /etc/resolv.conf << EOF
# Begin /etc/resolv.conf

domain $NET_DOMAIN
nameserver $NET_DNS

# End /etc/resolv.conf
EOF

    echo "$LFS_HOSTNAME" > /etc/hostname

    cat > /etc/hosts << EOF
# Begin /etc/hosts

127.0.0.1 localhost.localdomain localhost
127.0.1.1 $LFS_HOSTNAME.$NET_DOMAIN $LFS_HOSTNAME
$NET_IP $LFS_HOSTNAME.$NET_DOMAIN $LFS_HOSTNAME
::1       localhost ip6-localhost ip6-loopback
ff02::1   ip6-allnodes
ff02::2   ip6-allrouters

# End /etc/hosts
EOF
}

# 9.6 System V Bootscript Usage and Configuration
sysv_config() {
    cat > /etc/inittab << "EOF"
# Begin /etc/inittab

id:3:initdefault:

si::sysinit:/etc/rc.d/init.d/rc S

l0:0:wait:/etc/rc.d/init.d/rc 0
l1:S1:wait:/etc/rc.d/init.d/rc 1
l2:2:wait:/etc/rc.d/init.d/rc 2
l3:3:wait:/etc/rc.d/init.d/rc 3
l4:4:wait:/etc/rc.d/init.d/rc 4
l5:5:wait:/etc/rc.d/init.d/rc 5
l6:6:wait:/etc/rc.d/init.d/rc 6

ca:12345:ctrlaltdel:/sbin/shutdown -t1 -a -r now

su:S06:once:/sbin/sulogin
s1:1:respawn:/sbin/sulogin

1:2345:respawn:/sbin/agetty --noclear tty1 9600
2:2345:respawn:/sbin/agetty tty2 9600
3:2345:respawn:/sbin/agetty tty3 9600
4:2345:respawn:/sbin/agetty tty4 9600
5:2345:respawn:/sbin/agetty tty5 9600
6:2345:respawn:/sbin/agetty tty6 9600

# End /etc/inittab
EOF

    cat > /etc/sysconfig/clock << EOF
# Begin /etc/sysconfig/clock

UTC=$HWCLOCK_UTC

# Set this to any options you might need to give to hwclock,
# such as machine hardware clock type for Alphas.
CLOCKPARAMS=

# End /etc/sysconfig/clock
EOF

    # Vérifie que le clavier et la police existent bien (kbd, 8.67)
    find /usr/share/keymaps -name "$CONSOLE_KEYMAP.map*" | grep . >/dev/null \
        || { echo "keymap '$CONSOLE_KEYMAP' introuvable dans /usr/share/keymaps"; exit 1; }
    ls /usr/share/consolefonts/"$CONSOLE_FONT".* >/dev/null \
        || { echo "police '$CONSOLE_FONT' introuvable dans /usr/share/consolefonts"; exit 1; }

    cat > /etc/sysconfig/console << EOF
# Begin /etc/sysconfig/console

UNICODE="1"
KEYMAP="$CONSOLE_KEYMAP"
FONT="$CONSOLE_FONT"

# End /etc/sysconfig/console
EOF
}

# 9.7 Configuring the System Locale
locale_config() {
    # Vérification proposée par le livre : la locale doit exister
    # (locale -a écrit fr_FR.utf8 pour fr_FR.UTF-8)
    locale -a | grep -x "${LFS_LANG/UTF-8/utf8}" >/dev/null \
        || { echo "locale $LFS_LANG absente (localedef en 8.5)"; exit 1; }
    LC_ALL=$LFS_LANG locale charmap

    cat > /etc/profile << EOF
# Begin /etc/profile

for i in \$(locale); do
  unset \${i%=*}
done

if [[ "\$TERM" = linux ]]; then
  export LANG=C.UTF-8
else
  export LANG=$LFS_LANG
fi

# End /etc/profile
EOF
}

# 9.8 Creating the /etc/inputrc File
inputrc() {
    cat > /etc/inputrc << "EOF"
# Begin /etc/inputrc
# Modified by Chris Lynn <roryo@roryo.dynup.net>

# Allow the command prompt to wrap to the next line
set horizontal-scroll-mode Off

# Enable 8-bit input
set meta-flag On
set input-meta On

# Turns off 8th bit stripping
set convert-meta Off

# Keep the 8th bit for display
set output-meta On

# none, visible or audible
set bell-style none

# All of the following map the escape sequence of the value
# contained in the 1st argument to the readline specific functions
"\eOd": backward-word
"\eOc": forward-word

# for linux console
"\e[1~": beginning-of-line
"\e[4~": end-of-line
"\e[5~": beginning-of-history
"\e[6~": end-of-history
"\e[3~": delete-char
"\e[2~": quoted-insert

# for xterm
"\eOH": beginning-of-line
"\eOF": end-of-line

# for Konsole
"\e[H": beginning-of-line
"\e[F": end-of-line

# End /etc/inputrc
EOF
}

# 9.9 Creating the /etc/shells File
etc_shells() {
    cat > /etc/shells << "EOF"
# Begin /etc/shells

/bin/sh
/bin/bash

# End /etc/shells
EOF
}

build 09.02-bootscripts  lfs-bootscripts  bootscripts_pkg
step  09.05-network                       network
step  09.06-sysv-config                   sysv_config
step  09.07-locale                        locale_config
step  09.08-inputrc                       inputrc
step  09.09-shells                        etc_shells

echo
echo "Chapitre 9 terminé. Suite : ./22_enter_chroot.sh 51_ch10_boot.sh"
