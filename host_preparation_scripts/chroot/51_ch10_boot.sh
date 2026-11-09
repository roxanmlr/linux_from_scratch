#!/bin/bash
# LFS 12.4 - Chapitre 10 : rendre le système démarrable, DANS le chroot
#   Sur l'hôte :  ./22_enter_chroot.sh 51_ch10_boot.sh
#   Valeurs    :  chroot/ft_config.sh   (LOOP est transmis par 22_enter_chroot.sh)
#
# Disque : image GPT/BIOS avec p1 bios_grub, p2 /boot, p3 swap, p4 racine.
# Les noms de périphériques changent entre l'hôte (/dev/loopXpY) et la VM
# (/dev/sdaY, /dev/vdaY...) : fstab utilise les UUID, le noyau root=PARTUUID
# (le livre précise que root=UUID= demanderait un initramfs).
source "$(dirname "$0")/chroot_lib.sh"
chroot_init
need_stamp 09.09-shells

set -a
source "$(dirname "$0")/ft_config.sh"
set +a

[ -n "${LOOP:-}" ] && [ -b "$LOOP" ] || die "LOOP absent : lance ce script via 22_enter_chroot.sh (env.sh doit définir LOOP)"
mountpoint -q /boot || die "/boot n'est pas monté dans le chroot (07_mounting.sh sur l'hôte)"

export LOOP
export ROOT_UUID BOOT_UUID SWAP_UUID ROOT_PARTUUID
ROOT_UUID=$(blkid -s UUID -o value "${LOOP}p4")
BOOT_UUID=$(blkid -s UUID -o value "${LOOP}p2")
SWAP_UUID=$(blkid -s UUID -o value "${LOOP}p3")
ROOT_PARTUUID=$(blkid -s PARTUUID -o value "${LOOP}p4")
for v in ROOT_UUID BOOT_UUID SWAP_UUID ROOT_PARTUUID; do
    [ -n "${!v}" ] || die "$v vide (blkid sur ${LOOP}pX)"
    echo "$v=${!v}"
done

# 10.2 Creating the /etc/fstab File
fstab() {
    cat > /etc/fstab << EOF
# Begin /etc/fstab

# file system  mount-point    type     options             dump  fsck
#                                                                order

UUID=$ROOT_UUID  /          ext4     defaults            1     1
UUID=$BOOT_UUID  /boot      ext4     defaults            1     2
UUID=$SWAP_UUID  swap       swap     pri=1               0     0
proc           /proc          proc     nosuid,noexec,nodev 0     0
sysfs          /sys           sysfs    nosuid,noexec,nodev 0     0
devpts         /dev/pts       devpts   gid=5,mode=620      0     0
tmpfs          /run           tmpfs    defaults            0     0
devtmpfs       /dev           devtmpfs mode=0755,nosuid    0     0
tmpfs          /dev/shm       tmpfs    nosuid,nodev        0     0
cgroup2        /sys/fs/cgroup cgroup2  nosuid,noexec,nodev 0     0

# End /etc/fstab
EOF
    cat /etc/fstab
}

# 10.3 Linux : configuration non interactive
# Options demandées par le livre + pilotes de VM en dur (=y), pour démarrer
# sans initramfs sous QEMU/KVM, VirtualBox ou VMware.
kernel_configure() {
    if [ -s "$KERNEL_CONFIG_FILE" ]; then
        echo "Configuration reprise de $KERNEL_CONFIG_FILE"
        cp -v "$KERNEL_CONFIG_FILE" .config
    else
        make defconfig
    fi

    local c=scripts/config
    # --- Livre, 10.3
    $c --disable WERROR
    $c --enable  PSI            --disable PSI_DEFAULT_DISABLED
    $c --disable IKHEADERS
    $c --enable  CGROUPS        --enable MEMCG
    $c --disable EXPERT
    $c --enable  RELOCATABLE    --enable RANDOMIZE_BASE
    $c --enable  X86_X2APIC
    $c --enable  STACKPROTECTOR --enable STACKPROTECTOR_STRONG
    $c --disable UEVENT_HELPER
    $c --enable  DEVTMPFS       --enable DEVTMPFS_MOUNT
    $c --enable  SYSFB_SIMPLEFB
    $c --enable  DRM --enable DRM_PANIC --set-str DRM_PANIC_SCREEN kmsg
    $c --enable  DRM_FBDEV_EMULATION --enable DRM_SIMPLEDRM
    $c --enable  FRAMEBUFFER_CONSOLE
    $c --enable  PCI --enable PCI_MSI
    $c --enable  IOMMU_SUPPORT --enable IRQ_REMAP
    $c --enable  BLK_DEV_NVME

    # --- Version : login dans uname -r (sujet ft_linux)
    $c --set-str LOCALVERSION "$KLOCALVERSION" --disable LOCALVERSION_AUTO

    # --- Disque et système de fichiers en dur (pas d'initramfs)
    $c --enable EXT4_FS --enable BLK_DEV_SD --enable ATA --enable SATA_AHCI --enable ATA_PIIX
    $c --enable HYPERVISOR_GUEST --enable PARAVIRT --enable KVM_GUEST
    $c --enable VIRTIO_MENU --enable VIRTIO_PCI --enable VIRTIO_BLK --enable SCSI_VIRTIO
    $c --enable VIRTIO_NET --enable VIRTIO_CONSOLE
    $c --enable VMWARE_PVSCSI --enable VMXNET3
    # --- Réseau
    $c --enable E1000 --enable E1000E
    # --- Affichage (Xorg plus tard : pilote DRM du noyau obligatoire)
    $c --enable DRM_VIRTIO_GPU --enable DRM_BOCHS --enable DRM_VMWGFX
    $c --enable DRM_VBOXVIDEO  --enable DRM_VGEM
    $c --enable INPUT_EVDEV

    make olddefconfig

    # Contrôle : olddefconfig retire en silence ce dont les dépendances manquent
    local miss=0 o
    for o in DEVTMPFS DEVTMPFS_MOUNT EXT4_FS BLK_DEV_SD SATA_AHCI VIRTIO_BLK; do
        grep -q "^CONFIG_$o=y" .config || { echo "BLOQUANT : CONFIG_$o n'est pas =y"; miss=1; }
    done
    for o in PSI CGROUPS MEMCG RELOCATABLE RANDOMIZE_BASE X86_X2APIC STACKPROTECTOR_STRONG \
             SYSFB_SIMPLEFB DRM DRM_PANIC DRM_FBDEV_EMULATION DRM_SIMPLEDRM FRAMEBUFFER_CONSOLE \
             PCI_MSI IOMMU_SUPPORT IRQ_REMAP VIRTIO_NET E1000 E1000E DRM_VIRTIO_GPU DRM_BOCHS \
             DRM_VMWGFX DRM_VBOXVIDEO DRM_VGEM INPUT_EVDEV; do
        grep -q "^CONFIG_$o=y" .config || echo "avertissement : CONFIG_$o absent après olddefconfig"
    done
    [ $miss -eq 0 ]
}

# 10.3 Linux
kernel_pkg() {
    make mrproper
    kernel_configure
    make

    local kver; kver=$(make -s kernelrelease)
    echo "Version du noyau : $kver"
    make modules_install

    cp -v arch/x86/boot/bzImage /boot/vmlinuz-$kver
    cp -v System.map            /boot/System.map-$kver
    cp -v .config               /boot/config-$kver
    # Copie réutilisable pour une prochaine compilation (KERNEL_CONFIG_FILE)
    cp -v .config               "$KERNEL_CONFIG_FILE"
    echo "$kver" > /boot/.ft_kernel_release

    cp -r Documentation -T /usr/share/doc/${P}

    install -v -m755 -d /etc/modprobe.d
    cat > /etc/modprobe.d/usb.conf << "EOF"
# Begin /etc/modprobe.d/usb.conf

install ohci_hcd /sbin/modprobe ehci_hcd ; /sbin/modprobe -i ohci_hcd ; true
install uhci_hcd /sbin/modprobe ehci_hcd ; /sbin/modprobe -i uhci_hcd ; true

# End /etc/modprobe.d/usb.conf
EOF
}

# 10.4 GRUB (BIOS, image GPT avec partition bios_grub)
grub() {
    local kver; kver=$(cat /boot/.ft_kernel_release)
    [ -e /boot/vmlinuz-$kver ] || { echo "/boot/vmlinuz-$kver absent"; exit 1; }

    grub-install --target=i386-pc "$LOOP"

    cat > /boot/grub/grub.cfg << EOF
# Begin /boot/grub/grub.cfg
set default=0
set timeout=5

insmod part_gpt
insmod ext2
# /boot séparé : root GRUB = partition de boot, chemins relatifs à elle
search --no-floppy --set=root --fs-uuid $BOOT_UUID
set gfxpayload=1024x768x32

menuentry "GNU/Linux, Linux $kver" {
        linux   /vmlinuz-$kver root=PARTUUID=$ROOT_PARTUUID ro net.ifnames=0
}
EOF
    cat /boot/grub/grub.cfg
}

step  10.02-fstab                fstab
build 10.03-kernel  linux        kernel_pkg
step  10.04-grub                 grub

echo
echo "Chapitre 10 terminé. Noyau : $(cat /boot/.ft_kernel_release)"
echo "Ensuite : passwd root si pas fait, puis sur l'hôte 23_umount_vfs.sh et 99_umount.sh avant de démarrer la VM."
