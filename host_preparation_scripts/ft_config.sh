# Configuration de TON système, lue par 50_ch9_config.sh et 51_ch10_boot.sh.
# Modifie ces valeurs puis relance le script concerné
# (après avoir supprimé le tampon de l'étape à refaire dans /sources/.stamps).

# --- Identité (sujet ft_linux : hostname = ton login, login dans la version du noyau)
LFS_HOSTNAME="lmilando"
KLOCALVERSION="-lmilando"          # uname -r donnera 6.16.1-lmilando

# --- Réseau (9.5) : interface eth0 grâce à net.ifnames=0 sur la ligne du noyau
# Valeurs par défaut = NAT de QEMU (user-mode) et de VirtualBox
NET_IFACE="eth0"
NET_IP="10.0.2.15"
NET_PREFIX="24"
NET_BROADCAST="10.0.2.255"
NET_GATEWAY="10.0.2.2"
NET_DNS="10.0.2.3"
NET_DOMAIN="localdomain"

# --- Langue et console (9.6, 9.7)
LFS_LANG="fr_FR.UTF-8"             # doit faire partie des locales créées en 8.5
CONSOLE_KEYMAP="fr"                # clavier AZERTY ; "us" pour QWERTY
CONSOLE_FONT="Lat2-Terminus16"
XKB_LAYOUT="fr"                    # clavier sous X (us pour QWERTY)
HWCLOCK_UTC=1                      # 1 = horloge matérielle en UTC (normal en VM)

# --- Noyau (10.3) : fichier .config déjà prêt, utilisé tel quel s'il existe
# (sinon : defconfig + options du livre + pilotes de VM, voir 51_ch10_boot.sh)
KERNEL_CONFIG_FILE="/sources/ft_kernel.config"

# --- Démarrage graphique (73_blfs_openbox.sh)
# startx automatique après connexion sur tty1 (les connexions SSH ne sont pas concernées)
X_AUTOSTART=1
# Connexion automatique de cet utilisateur sur tty1 ("" = garder la demande de mot de passe)
AUTOLOGIN_USER=""
