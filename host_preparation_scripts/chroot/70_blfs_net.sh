#!/bin/bash
# BLFS 12.4 (sysv), lot réseau, DANS le chroot :
#   libtasn1 -> p11-kit -> make-ca -> libunistring -> libidn2 -> libpsl
#   -> curl -> wget -> OpenSSH (+ bootscript sshd) -> utilisateur pour SSH
#   Sur l'hôte :  ./70_get_blfs_sources.sh blfs/10_net.list
#                 ./21_mount_vfs.sh && ./22_enter_chroot.sh 70_blfs_net.sh
# BLFS compile en utilisateur et installe en root ; ici tout se fait en root
# dans le chroot, comme pour le chapitre 8.
source "$(dirname "$0")/chroot_lib.sh"
chroot_init
need_stamp 10.04-grub

set -a
source "$(dirname "$0")/ft_config.sh"
set +a
export SSH_USER="${SSH_USER:-$LFS_HOSTNAME}"

# libtasn1
libtasn1_pkg() {
    ./configure --prefix=/usr --disable-static
    make
    t make check
    make install
    make -C doc/reference install-data-local
}

# p11-kit
p11_kit_pkg() {
    sed '20,$ d' -i trust/trust-extract-compat
    cat >> trust/trust-extract-compat << "EOF"
# Copy existing anchor modifications to /etc/ssl/local
/usr/libexec/make-ca/copy-trust-modifications

# Update trust stores
/usr/sbin/make-ca -r
EOF

    mkdir p11-build
    cd    p11-build
    meson setup ..            \
          --prefix=/usr       \
          --buildtype=release \
          -D trust_paths=/etc/pki/anchors
    ninja
    t env LC_ALL=C ninja test
    ninja install
    ln -sfv /usr/libexec/p11-kit/trust-extract-compat \
            /usr/bin/update-ca-certificates
}

# make-ca : télécharge certdata.txt de Mozilla (make-ca -g).
# Dans le chroot, /etc/resolv.conf contient le DNS de la VM (10.0.2.3), inutilisable
# depuis l'hôte : on prend le temps de l'étape celui de l'hôte (host-resolv.conf).
make_ca_pkg() {
    make install
    install -vdm755 /etc/ssl/local

    local saved=""
    if [ -s /sources/host-resolv.conf ]; then
        saved=$(mktemp)
        cp /etc/resolv.conf "$saved"
        cp /sources/host-resolv.conf /etc/resolv.conf
    fi
    local rc=0
    /usr/sbin/make-ca -g || rc=$?
    if [ -n "$saved" ]; then cp "$saved" /etc/resolv.conf; rm -f "$saved"; fi
    [ $rc -eq 0 ] || { echo "make-ca -g a échoué (réseau / DNS ?)"; exit 1; }

    echo "$(ls /etc/ssl/certs | wc -l) fichiers dans /etc/ssl/certs"
    [ -s /etc/pki/tls/certs/ca-bundle.crt ] || { echo "ca-bundle.crt absent"; exit 1; }
}

# libunistring
libunistring_pkg() {
    ./configure --prefix=/usr    \
                --disable-static \
                --docdir=/usr/share/doc/$P
    make
    t make check
    make install
}

# libidn2
libidn2_pkg() {
    ./configure --prefix=/usr --disable-static
    make
    t make check
    make install
}

# libpsl
libpsl_pkg() {
    mkdir build
    cd    build
    meson setup --prefix=/usr --buildtype=release
    ninja
    t ninja test
    ninja install
}

# cURL
curl_pkg() {
    ./configure --prefix=/usr    \
                --disable-static \
                --with-openssl   \
                --with-ca-path=/etc/ssl/certs
    make
    t make test
    make install

    rm -rf docs/examples/.deps
    find docs \( -name Makefile\* -o  \
                 -name \*.1       -o  \
                 -name \*.3       -o  \
                 -name CMakeLists.txt \) -delete
    cp -v -R docs -T /usr/share/doc/$P
}

# Wget
wget_pkg() {
    ./configure --prefix=/usr      \
                --sysconfdir=/etc  \
                --with-ssl=openssl
    make
    t make check
    make install
}

# OpenSSH
openssh_pkg() {
    install -v -g sys -m700 -d /var/lib/sshd
    getent group  sshd >/dev/null || groupadd -g 50 sshd
    getent passwd sshd >/dev/null || \
        useradd -c 'sshd PrivSep' \
                -d /var/lib/sshd  \
                -g sshd           \
                -s /bin/false     \
                -u 50 sshd

    ./configure --prefix=/usr                            \
                --sysconfdir=/etc/ssh                    \
                --with-privsep-path=/var/lib/sshd        \
                --with-default-path=/usr/bin             \
                --with-superuser-path=/usr/sbin:/usr/bin \
                --with-pid-dir=/run
    make
    t make -j1 tests
    make install
    install -v -m755    contrib/ssh-copy-id /usr/bin
    install -v -m644    contrib/ssh-copy-id.1 /usr/share/man/man1
    install -v -m755 -d /usr/share/doc/$P
    install -v -m644    INSTALL LICENCE OVERVIEW README* /usr/share/doc/$P

    # Recommandation BLFS : pas de connexion root par SSH (une seule fois)
    grep -q '^PermitRootLogin no' /etc/ssh/sshd_config \
        || echo "PermitRootLogin no" >> /etc/ssh/sshd_config

    # Clés d'hôte générées dès maintenant (sinon au premier démarrage de sshd)
    ssh-keygen -A
}

# Bootscript sshd (blfs-bootscripts) : S30sshd au niveau 3
sshd_bootscript() {
    make install-sshd
    ls -l /etc/rc.d/rc3.d/ | grep -i ssh
}

# Utilisateur normal pour se connecter en SSH (root est interdit)
ssh_user() {
    if ! id "$SSH_USER" &>/dev/null; then
        useradd -m -s /bin/bash -G users "$SSH_USER"
        echo "Utilisateur $SSH_USER créé, SANS mot de passe : passwd $SSH_USER à faire à la main."
    else
        echo "Utilisateur $SSH_USER déjà présent."
    fi
}

build 70.01-libtasn1        libtasn1          libtasn1_pkg
build 70.02-p11-kit         p11-kit           p11_kit_pkg
build 70.03-make-ca         make-ca           make_ca_pkg
build 70.04-libunistring    libunistring      libunistring_pkg
build 70.05-libidn2         libidn2           libidn2_pkg
build 70.06-libpsl          libpsl            libpsl_pkg
build 70.07-curl            curl              curl_pkg
build 70.08-wget            wget              wget_pkg
build 70.09-openssh         openssh           openssh_pkg
build 70.10-sshd-bootscript blfs-bootscripts  sshd_bootscript
step  70.11-ssh-user                          ssh_user

echo
echo "Lot réseau BLFS terminé."
echo "À faire à la main :  ./22_enter_chroot.sh   puis   passwd $SSH_USER"
echo "Puis : 23_umount_vfs.sh, 99_umount.sh, REFRESH=1 ./60_virtualbox_vm.sh"
echo "Connexion depuis l'hôte : ssh -p 2222 $SSH_USER@localhost"
