#!/usr/bin/env bash
# Crée (ou met à jour) une VM VirtualBox qui démarre disk.raw, puis la lance.
#   ./60_virtualbox_vm.sh                 crée la VM au premier lancement, la démarre ensuite
#   REFRESH=1 ./60_virtualbox_vm.sh       reconvertit disk.raw -> VDI (après un build dans le chroot)
#   HEADLESS=1 ./60_virtualbox_vm.sh      sans fenêtre (accès par SSH plus tard : port 2222)
#
# VirtualBox ne sait pas démarrer un .raw directement : l'image est convertie en VDI.
# Attention : la VM travaille alors sur sa copie VDI, pas sur disk.raw.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"

VM="${VM_NAME:-ft_linux}"
RAW="$DIR/disk.raw"
VDI="$DIR/ft_linux.vdi"
MEM="${VM_MEM:-4096}"
CPUS="${VM_CPUS:-4}"

command -v VBoxManage >/dev/null || { echo "VBoxManage introuvable : installe VirtualBox"; exit 1; }
[ -f "$RAW" ] || { echo "$RAW introuvable"; exit 1; }

# L'image ne doit plus être utilisée par l'hôte (sinon la copie peut être incohérente)
if [ -n "$(losetup -j "$RAW" 2>/dev/null)" ]; then
    echo "disk.raw est encore attaché à un loop device : lance ./23_umount_vfs.sh puis ./99_umount.sh"
    exit 1
fi

vm_exists()  { VBoxManage showvminfo "$VM" &>/dev/null; }
vm_running() { VBoxManage showvminfo "$VM" --machinereadable 2>/dev/null | grep '^VMState="running"' >/dev/null; }

if vm_exists && vm_running; then
    echo "La VM $VM tourne déjà. Arrête-la avant (poweroff dans la VM)."
    exit 1
fi

# --- Disque : conversion RAW -> VDI au premier lancement ou si REFRESH=1
if [ ! -f "$VDI" ] || [ "${REFRESH:-0}" = 1 ]; then
    if [ -f "$VDI" ]; then
        read -rp "Remplacer $VDI ? Les changements faits DANS la VM seront perdus. [y/N] " r
        [ "$r" = y ] || exit 1
        if vm_exists; then
            VBoxManage storageattach "$VM" --storagectl SATA --port 0 --device 0 --medium none || true
        fi
        VBoxManage closemedium disk "$VDI" 2>/dev/null || true
        rm -f "$VDI"
    fi
    echo "Conversion $RAW -> $VDI ..."
    VBoxManage convertfromraw "$RAW" "$VDI" --format VDI
fi

# --- Création de la VM (une seule fois)
if ! vm_exists; then
    VBoxManage createvm --name "$VM" --ostype Linux_64 --register

    # BIOS (pas d'EFI) : GRUB est installé en i386-pc avec une partition bios_grub
    # Carte réseau Intel PRO/1000 (e1000, intégrée au noyau) en NAT :
    #   IP 10.0.2.15, passerelle 10.0.2.2, DNS 10.0.2.3 (= ft_config.sh)
    # VMSVGA : pilote vmwgfx, intégré au noyau (utile pour Xorg)
    # rtcuseutc : horloge matérielle en UTC (UTC=1 dans /etc/sysconfig/clock)
    VBoxManage modifyvm "$VM"                 \
        --memory "$MEM" --cpus "$CPUS"        \
        --firmware bios --ioapic on           \
        --rtcuseutc on                        \
        --graphicscontroller vmsvga --vram 128 \
        --nic1 nat --nictype1 82540EM         \
        --natpf1 "ssh,tcp,,2222,,22"          \
        --boot1 disk --boot2 none --boot3 none --boot4 none

    VBoxManage storagectl "$VM" --name SATA --add sata \
        --controller IntelAhci --portcount 1 --bootable on
fi

# --- Disque attaché au contrôleur SATA (AHCI, intégré au noyau)
VBoxManage storageattach "$VM" --storagectl SATA --port 0 --device 0 \
    --type hdd --medium "$VDI"

echo
VBoxManage showvminfo "$VM" | grep -E '^(Name|Memory size|Number of CPUs|Firmware|Graphics Controller|NIC 1|SATA)' || true
echo

START_TYPE=gui
[ "${HEADLESS:-0}" = 1 ] && START_TYPE=headless

start_vm() {
    local out rc=0
    out="$(VBoxManage startvm "$VM" --type "$START_TYPE" 2>&1)" || rc=$?
    echo "$out"
    START_OUT="$out"
    return $rc
}

# Module chargé ? (lu dans /proc/modules : « lsmod | grep -q » peut échouer
# avec pipefail, grep -q fermant le tube avant la fin de lsmod)
kmod_loaded() { grep -q "^$1 " /proc/modules; }

# Décharge KVM, qui occupe VT-x / AMD-V et empêche VirtualBox de démarrer
unload_kvm() {
    local m
    echo ">> KVM occupe la virtualisation matérielle : déchargement des modules kvm"
    for m in kvm_intel kvm_amd kvm; do
        if kmod_loaded "$m"; then
            if ! sudo modprobe -r "$m"; then
                echo "!! Impossible de décharger $m : il est utilisé."
                echo "   Ferme les VM QEMU/KVM (virt-manager, GNOME Boxes...) et arrête libvirt :"
                echo "     sudo systemctl stop libvirtd virtqemud 2>/dev/null"
                echo "   puis relance ce script. Utilisateurs actuels :"
                grep '^kvm' /proc/modules || true
                return 1
            fi
            echo "   $m déchargé"
        fi
    done
    if kmod_loaded kvm; then
        echo "!! KVM toujours chargé"; return 1
    fi
    echo "   (pour le recharger plus tard : sudo modprobe kvm_intel   ou kvm_amd)"
    echo "   Correctif durable (noyau >= 6.12) : KVM ne prend VT-x que pendant ses propres VM avec"
    echo "     sudo grubby --update-kernel=ALL --args=kvm.enable_virt_at_load=0   puis redémarrage"
}

if ! start_vm; then
    if grep -qE 'VERR_VMX_IN_VMX_ROOT_MODE|VERR_SVM_IN_USE' <<<"$START_OUT"; then
        if kmod_loaded kvm || kmod_loaded kvm_intel || kmod_loaded kvm_amd; then
            unload_kvm || exit 1
            echo ">> Nouvel essai de démarrage"
            start_vm || exit 1
        else
            echo "!! VT-x/AMD-V est occupé, mais aucun module kvm n'est chargé. Diagnostic :"
            echo "   noyau hôte      : $(uname -r)"
            echo "   hôte virtualisé : $(systemd-detect-virt 2>/dev/null || echo inconnu)"
            echo "   /dev/kvm        : $([ -e /dev/kvm ] && echo présent || echo absent)"
            if grep -qs '/kvm' "/lib/modules/$(uname -r)/modules.builtin"; then
                echo "   KVM compilé DANS le noyau (modules.builtin) : impossible à décharger"
            fi
            echo "   processus d'hyperviseur :"
            pgrep -a -f 'qemu|vmware-vmx|firecracker|crosvm|libvirtd' | sed 's/^/     /' || echo "     aucun"
            echo "   -> Si /dev/kvm est présent, démarre plutôt l'image avec QEMU/KVM (61_qemu_vm.sh)."
            exit 1
        fi
    else
        exit 1
    fi
fi
