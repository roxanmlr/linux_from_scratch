#!/bin/bash
# LFS 12.4 - Chapitre 7 (7.5 à 7.13.1), DANS le chroot, en root.
# Lancé depuis l'hôte par : ./22_enter_chroot.sh 30_chroot_tools.sh
# Reprenable : relancer reprend à la première étape non terminée.
source "$(dirname "$0")/chroot_lib.sh"
chroot_init

# 7.5 Creating Directories
dirs() {
    mkdir -pv /{boot,home,mnt,opt,srv}
    mkdir -pv /etc/{opt,sysconfig}
    mkdir -pv /lib/firmware
    mkdir -pv /media/{floppy,cdrom}
    mkdir -pv /usr/{,local/}{include,src}
    mkdir -pv /usr/lib/locale
    mkdir -pv /usr/local/{bin,lib,sbin}
    mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man}
    mkdir -pv /usr/{,local/}share/{misc,terminfo,zoneinfo}
    mkdir -pv /usr/{,local/}share/man/man{1..8}
    mkdir -pv /var/{cache,local,log,mail,opt,spool}
    mkdir -pv /var/lib/{color,misc,locate}

    ln -sfv /run /var/run
    ln -sfv /run/lock /var/lock

    install -dv -m 0750 /root
    install -dv -m 1777 /tmp /var/tmp
}

# 7.6 Creating Essential Files and Symlinks
files() {
    ln -sfv /proc/self/mounts /etc/mtab

    cat > /etc/hosts << EOF
127.0.0.1  localhost $(hostname)
::1        localhost
EOF

    cat > /etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/usr/bin/false
daemon:x:6:6:Daemon User:/dev/null:/usr/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/run/dbus:/usr/bin/false
uuidd:x:80:80:UUID Generation Daemon User:/dev/null:/usr/bin/false
nobody:x:65534:65534:Unprivileged User:/dev/null:/usr/bin/false
EOF

    cat > /etc/group << "EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
input:x:24:
mail:x:34:
kvm:x:61:
uuidd:x:80:
wheel:x:97:
users:x:999:
nogroup:x:65534:
EOF

    # Utilisateur de test du chapitre 8 (les fichiers viennent d'être réécrits, pas de doublon)
    echo "tester:x:101:101::/home/tester:/bin/bash" >> /etc/passwd
    echo "tester:x:101:" >> /etc/group
    install -o tester -d /home/tester

    # (le livre fait ici « exec /usr/bin/bash --login » : seulement pour le prompt)

    touch /var/log/{btmp,lastlog,faillog,wtmp}
    chgrp -v utmp /var/log/lastlog
    chmod -v 664  /var/log/lastlog
    chmod -v 600  /var/log/btmp
}

# 7.7 Gettext
gettext_pkg() {
    ./configure --disable-shared
    make
    cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin
}

# 7.8 Bison
bison_pkg() {
    ./configure --prefix=/usr \
                --docdir=/usr/share/doc/bison-$(pkg_version bison)
    make
    make install
}

# 7.9 Perl
perl_pkg() {
    local pv; pv="$(pkg_version perl | cut -d. -f1,2)"   # 5.42
    sh Configure -des                                         \
                 -D prefix=/usr                               \
                 -D vendorprefix=/usr                         \
                 -D useshrplib                                \
                 -D privlib=/usr/lib/perl5/$pv/core_perl      \
                 -D archlib=/usr/lib/perl5/$pv/core_perl      \
                 -D sitelib=/usr/lib/perl5/$pv/site_perl      \
                 -D sitearch=/usr/lib/perl5/$pv/site_perl     \
                 -D vendorlib=/usr/lib/perl5/$pv/vendor_perl  \
                 -D vendorarch=/usr/lib/perl5/$pv/vendor_perl
    make
    make install
}

# 7.10 Python
python_pkg() {
    ./configure --prefix=/usr       \
                --enable-shared     \
                --without-ensurepip \
                --without-static-libpython
    make
    make install
}

# 7.11 Texinfo
texinfo_pkg() {
    ./configure --prefix=/usr
    make
    make install
}

# 7.12 Util-linux
util_linux_pkg() {
    mkdir -pv /var/lib/hwclock
    ./configure --libdir=/usr/lib     \
                --runstatedir=/run    \
                --disable-chfn-chsh   \
                --disable-login       \
                --disable-nologin     \
                --disable-su          \
                --disable-setpriv     \
                --disable-runuser     \
                --disable-pylibmount  \
                --disable-static      \
                --disable-liblastlog2 \
                --without-python      \
                ADJTIME_PATH=/var/lib/hwclock/adjtime \
                --docdir=/usr/share/doc/util-linux-$(pkg_version util-linux)
    make
    make install
}

# 7.13.1 Cleaning
cleanup() {
    rm -rf /usr/share/{info,man,doc}/*
    find /usr/{lib,libexec} -name \*.la -delete
    rm -rf /tools
}

step  07.5-dirs                    dirs
step  07.6-files                   files
build 07.7-gettext     gettext     gettext_pkg
build 07.8-bison       bison       bison_pkg
build 07.9-perl        perl        perl_pkg
build 07.10-python     Python      python_pkg
build 07.11-texinfo    texinfo     texinfo_pkg
build 07.12-util-linux util-linux  util_linux_pkg
step  07.13-cleanup                cleanup

echo
echo "Chapitre 7 terminé. Sur l'hôte : 23_umount_vfs.sh puis (conseillé) 24_backup_temp_tools.sh"
