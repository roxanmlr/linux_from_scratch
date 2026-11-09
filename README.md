*This project has been created as part of the 42 curriculum by lmilando.*

# ft_linux

## Description

**ft_linux** is my own GNU/Linux distribution, built entirely from source code. No package comes from an existing distribution: the toolchain, the C library, the kernel, the init system, the bootloader and every program are compiled and assembled by the scripts in this repository, starting from an empty disk image.

The goal is to understand what a Linux system is actually made of and how its pieces fit together: how a cross toolchain is bootstrapped, why the C library and compiler are built several times, how the kernel, udev, the init scripts and GRUB cooperate at boot, and how a graphical stack is assembled from the kernel DRM driver up to the desktop.

### Overview

| | |
|---|---|
| Architecture | x86_64, BIOS boot (GRUB `i386-pc`) |
| Disk | One GPT disk image (`disk.raw`, 40 GB): `/boot`, swap and root partitions |
| Init system | SysVinit with System V boot scripts and runlevels |
| Kernel | Linux 6.16.1, release string `6.16.1-lmilando`, sources in `/usr/src/kernel-6.16.1` |
| Device manager / module loader | udev |
| Hostname | `lmilando` |
| Network / remote access | static IPv4, curl, wget, OpenSSH (`sshd` started at boot) |
| Graphics (bonus) | Xorg-Server 21.1 + Mesa (svga, softpipe), **Xfce 4.20** desktop (default) or Openbox 3.6 |
| Hypervisor | VirtualBox (BIOS, SATA AHCI, Intel PRO/1000, VMSVGA) |
| Build host | RPM-based distribution (RHEL / Rocky / Alma / Fedora) |

Every build step is a shell script. Long builds are **resumable**: each finished step leaves a stamp. After a failure, you fix the cause and rerun the same script, which skips what is done and restarts the failed package from a fresh copy of its sources.

### Features

- The whole distribution is scripted, from creating the disk image to installing GRUB.
- All packages required by the subject (see [Required packages](#required-packages)).
- Networking: CA certificates (make-ca), curl, wget, and an OpenSSH server started at boot.
- Graphical environment (bonus): Xorg, the Xfce 4.20 desktop and the Openbox window manager. `startx` can run automatically after login on tty1.
- `80_check_ft_linux.sh` checks every mandatory requirement of the subject inside the running VM (87 checks).
- Each build step runs in its own `bash` with `set -euo pipefail`, has its own log, and is stamped when it succeeds.
- Test suites are configurable. They never block the build, and failures are collected into a single summary.
- Safety checks protect the host. Toolchain builds refuse to run as root, chroot scripts refuse to run outside the chroot, and destructive host scripts check that `$LFS` is valid and mounted.
- One script creates and starts the VirtualBox VM. It converts the raw image and, if needed, unloads KVM, which otherwise blocks VirtualBox.

### Repository layout

```
.
├── README.md
├── disk.sha1                    # checksum of the submitted disk image (see "Submission")
├── .gitignore
├── host/                        # run on the host, as a normal user (the scripts call sudo)
│   ├── env.sh                   # shared variables: LFS, LOOP, need_loop()
│   │
│   │   # Disk image and sources
│   ├── 00_create_disk.sh        # sparse disk.raw
│   ├── 01_loop_disk.sh          # attach disk.raw to a loop device (.loopdev)
│   ├── 02_parted_disk.sh        # GPT: bios_grub / boot / swap / root
│   ├── 03_format_partitions.sh  # ext4 + swap, with labels
│   ├── 04_show_partitions.sh
│   ├── 05_versions_check.sh     # build host requirements
│   ├── 07_mounting.sh           # mount root and /boot on /mnt/ft_linux
│   ├── 08_get_sources.sh        # base system sources + MD5 check, with mirror fallback
│   ├── 09_creating_limited_dir_layout.sh   # minimal directory layout (usr, lib64, tools)
│   ├── 09_reset_lfs.sh          # wipe the image back to that minimal layout
│   ├── 10_adding_ft_linux_user.sh          # unprivileged build user
│   │
│   │   # Chroot management
│   ├── 20_chown_root.sh         # give the new system back to root
│   ├── 21_mount_vfs.sh          # mount /dev, /proc, /sys, /run (every session)
│   ├── 22_enter_chroot.sh       # interactive shell, or run a chroot/ script
│   ├── 23_umount_vfs.sh
│   ├── 24_backup_temp_tools.sh  # checkpoint of the temporary system
│   ├── 25_restore_temp_tools.sh
│   │
│   │   # Virtual machine and extra sources
│   ├── 60_virtualbox_vm.sh      # create / refresh / start the VirtualBox VM
│   ├── 70_get_blfs_sources.sh   # download an extra batch and check MD5 sums
│   ├── 99_umount.sh             # unmount everything, detach the loop device
│   │
│   ├── blfs/                    # source lists of the extra batches: "<md5>  <url>" per line
│   │   ├── 10_net.list          # make-ca, curl, wget, OpenSSH
│   │   ├── 20_x_libs.list       # Xorg libraries
│   │   ├── 30_x_server.list     # Mesa, Xorg-Server, input drivers
│   │   ├── 40_openbox.list      # GLib, Pango, Openbox
│   │   ├── 50_gtk.list          # D-Bus, GTK 3, icons
│   │   └── 60_xfce.list         # Xfce 4.20
│   │
│   └── chroot/                  # copied to /sources/ft_scripts and run INSIDE the chroot
│       ├── chroot_lib.sh        # stamps, logs, test helper
│       ├── ft_config.sh         # hostname, network, keymaps, kernel, X session
│       ├── 30_chroot_tools.sh   # additional temporary tools, essential files
│       ├── 40_ch8_lot1.sh       # base system 1/4: man-pages, glibc, compression, tcl…
│       ├── 41_ch8_lot2.sh       # base system 2/4: binutils, gcc, shadow, bash…
│       ├── 42_ch8_lot3.sh       # base system 3/4: perl, openssl, python, meson…
│       ├── 43_ch8_lot4.sh       # base system 4/4: coreutils, grub, udev, sysvinit…
│       ├── 50_ch9_config.sh     # boot scripts, network, console, locale
│       ├── 51_ch10_boot.sh      # fstab, kernel, GRUB
│       ├── 52_kernel_sources.sh # kernel sources in /usr/src/kernel-<version>
│       ├── 70_blfs_net.sh       # make-ca, curl, wget, OpenSSH
│       ├── 71_blfs_x_libs.sh    # Xorg libraries, XCB, libdrm, Python modules
│       ├── 72_blfs_x_server.sh  # Mesa, Xorg apps/fonts, Xorg-Server, input, xterm
│       ├── 73_blfs_openbox.sh   # GLib, Cairo, Pango, Openbox, X autostart
│       ├── 74_blfs_gtk.sh       # D-Bus, GTK 3 and its dependencies, icons
│       ├── 75_blfs_xfce.sh      # Xfce 4.20 and the X session choice
│       └── 80_check_ft_linux.sh # checks the subject's requirements in the VM
└── toolchain/                   # run on the host as the ft_linux build user
    ├── build_env.sh             # clean, isolated build environment
    ├── build_lib.sh             # stamps and logs
    ├── 10_cross_toolchain.sh    # cross binutils, gcc, kernel headers, glibc, libstdc++
    └── 11_temp_tools.sh         # temporary tools cross-compiled for the new system
```

`22_enter_chroot.sh` copies **only** `host/chroot/*.sh` into the new system, so every script that runs inside it, plus `ft_config.sh`, must live in `chroot/`. The same scripts are also available in the booted VM under `/sources/ft_scripts/`.

The disk images (`disk.raw`, `ft_linux.vdi`) are created inside `host/` and are never committed:

```
# .gitignore
*.raw
*.raw.bak
*.vdi
.loopdev
```

### Disk layout

| Partition | Size  | Type      | Label           | Role                          |
|-----------|-------|-----------|-----------------|-------------------------------|
| p1        | 2 MiB | bios_grub | –               | GRUB core image (BIOS + GPT)  |
| p2        | 1 GiB | ext4      | `FT_LINUX_BOOT` | `/boot`                       |
| p3        | 4 GiB | swap      | `FT_LINUX_SWAP` | swap                          |
| p4        | rest  | ext4      | `FT_LINUX_ROOT` | `/`                           |

On the host, the new system is mounted on `/mnt/ft_linux` (`$LFS` in the scripts). The loop device is never hard-coded: `01_loop_disk.sh` stores it in `.loopdev`, and `env.sh` reads it back. In the VM, the same partitions appear as `/dev/sda2`, `/dev/sda3` and `/dev/sda4`.

### Build stages

1. **Host preparation:** create and partition the disk image, download and verify the sources, create an unprivileged build user.
2. **Cross toolchain:** build a cross binutils and gcc targeting `x86_64-ftlinux-linux-gnu`, then glibc and libstdc++ for the new system. This makes the new system independent from the host's libraries.
3. **Temporary tools:** cross-compile a minimal set of tools (bash, coreutils, make…) into the new system.
4. **Chroot:** switch into the new system and build the remaining temporary tools there.
5. **Base system:** build the final versions of every package, in dependency order, against the new glibc.
6. **Configuration and boot:** boot scripts, network, console, locale, `fstab`, kernel and GRUB.
7. **Extras:** networking tools, SSH server, then the graphical environment.

### Required packages

All packages required by the subject are installed:

Acl · Attr · Autoconf · Automake · Bash · Bc · Binutils · Bison · Bzip2 · Check · Coreutils · DejaGNU · Diffutils · udev (instead of Eudev) · E2fsprogs · Expat · Expect · File · Findutils · Flex · Gawk · GCC · GDBM · Gettext · Glibc · GMP · Gperf · Grep · Groff · GRUB · Gzip · Iana-Etc · Inetutils · Intltool · IPRoute2 · Kbd · Kmod · Less · Libcap · Libpipeline · Libtool · M4 · Make · Man-DB · Man-pages · MPC · MPFR · Ncurses · Patch · Perl · Pkg-config (pkgconf) · Procps · Psmisc · Readline · Sed · Shadow · Sysklogd · Sysvinit · Tar · Tcl · Texinfo · Time Zone Data · Udev-lfs Tarball · Util-linux · Vim · XML::Parser · Xz Utils · Zlib

The subject allows equivalents: *"Some packages below (vim, bash, grub, udev) are examples. Feel free to change them by any equivalent you like."* udev is taken from the systemd sources and built standalone, which provides the same role and the same `libudev` API as Eudev. `pkg-config` is provided by pkgconf.

### Main programs and their roles

#### Tools used by the scripts

| Program | Used in | Role |
|---------|---------|------|
| `truncate` | `00` | Creates `disk.raw` as a sparse file: 40 GB declared, only written blocks use space |
| `losetup -fP` | `01`, `99` | Attaches `disk.raw` to a free loop device and scans its partitions (`loopXp1..p4`) |
| `parted`, `partprobe` | `02` | Writes the GPT table and the four partitions, then makes the kernel re-read them |
| `sgdisk -e` | image resize | Moves the backup GPT header to the new end of a grown image |
| `mkfs.ext4`, `mkswap` | `03` | Create the filesystems and swap, with labels |
| `e2fsck`, `resize2fs` | image resize | Check, then grow the root filesystem |
| `mount`, `mountpoint`, `findmnt` | `07`, `21`, `23` | Mount root, `/boot` and the virtual filesystems; `mountpoint` makes the scripts idempotent |
| `wget`, `md5sum` | `08`, `70` | Download sources and check them against their published MD5 sums |
| `su`, `env -i` | `10`, `11` | Build the toolchain as the unprivileged `ft_linux` user, in an empty environment |
| `chroot` | `22` | Runs a shell or a script with `/mnt/ft_linux` as `/`, so packages are built against the new system |
| `tar`, `patch`, `sed` | every build step | Unpack sources, apply patches and source fixes |
| `./configure`, `make` | most packages | Autotools build: detect the system, compile, install |
| `meson`, `ninja` | newer packages (Kmod, udev, Mesa, Xorg-Server, GLib, GTK…) | Meson configures the build, Ninja runs it |
| `pip3 wheel` / `pip3 install` | Python modules | Build and install Python packages offline from their source tarballs |
| `ldconfig` | after libraries | Refreshes the dynamic linker cache |
| `strip`, `objcopy` | base system cleanup | Remove debug symbols to save space, keeping separate debug info for core libraries |
| `blkid` | `51` | Reads UUIDs and PARTUUIDs for `/etc/fstab` and the kernel command line |
| `scripts/config`, `make olddefconfig` | `51` | Set kernel options without the interactive `menuconfig` |
| `grub-install` | `51` | Writes GRUB's boot code to the disk and its core image into the `bios_grub` partition |
| `VBoxManage` | `60` | Converts the image to VDI, creates the VM, attaches the disk, starts it |
| `modprobe -r` | `60` | Unloads KVM when it blocks VirtualBox |

#### Components of the built system

| Component | Package | Role at runtime |
|-----------|---------|-----------------|
| Bootloader | GRUB | Loaded by the BIOS; finds `/boot` by UUID, loads the kernel with `root=PARTUUID=… net.ifnames=0` |
| Kernel | Linux 6.16.1-lmilando | Drives the hardware (AHCI, e1000, vmwgfx…), mounts the root filesystem, starts `/sbin/init` |
| Init | SysVinit (`init`, `/etc/inittab`) | PID 1: runs the boot scripts for the runlevel, starts `agetty` on each console |
| Boot scripts | `/etc/rc.d/init.d/*` | Mount filesystems, start udev, syslog, network, D-Bus, `sshd`… |
| Device manager / module loader | udev | Creates device nodes and loads kernel modules as the kernel reports hardware |
| C library | Glibc | The C runtime and the dynamic loader (`/lib64/ld-linux-x86-64.so.2`) every program uses |
| Shell and base tools | Bash, Coreutils, Util-linux, Grep, Sed… | The command line; `agetty` and `mount` come from Util-linux |
| Accounts | Shadow | `useradd`, `passwd`, `/etc/shadow`, `login` rules |
| Logging | Sysklogd | Writes kernel and daemon messages to `/var/log/*.log` |
| Network | IPRoute2, Inetutils | `ip` configures `eth0` from `/etc/sysconfig/ifconfig.eth0`; `ping`, `hostname`… |
| Certificates | make-ca, p11-kit | Mozilla's CA store in `/etc/ssl/certs`, used by curl, wget and OpenSSL |
| Downloads | curl, wget | HTTP(S) clients |
| Remote access | OpenSSH (`sshd`) | SSH server started at boot; root login disabled |
| Compiler toolchain | GCC, Binutils, Make, Autotools, Meson | Build and install further software directly on the new system |
| Message bus | D-Bus | System bus at boot; session bus started by `dbus-launch` for Xfce |
| Display server | Xorg-Server (+ `Xorg.wrap`) | Draws on screen through the kernel DRM driver (`modesetting` + vmwgfx) and reads input via libinput |
| OpenGL | Mesa (`svga`, `softpipe`) | 3D through VirtualBox's VMSVGA, with a software fallback |
| Session start | xinit (`startx`) | Starts the X server and runs `~/.xinitrc` |
| Toolkit | GTK 3, GLib, Pango, Cairo, gdk-pixbuf | Widgets, text and images for Xfce applications |
| Desktop | Xfce 4.20 (xfwm4, xfce4-panel, xfdesktop, Thunar, xfce4-settings, xfce4-session) | Window manager, panel, desktop, file manager, settings and session |
| Alternative window manager | Openbox | Lightweight session, selectable with `X_SESSION=openbox` |
| Terminal | xterm | Terminal emulator under X |
| Fonts and icons | Xorg Fonts, DejaVu, Fontconfig, FreeType, lxde-icon-theme | Font files, discovery and rendering; PNG icon theme `nuoveXT2` |

### Technical choices

| Area | Choice | Reason |
|------|--------|--------|
| Cross triplet | `x86_64-ftlinux-linux-gnu` | Own vendor field. The OS part must stay `linux-gnu`: `x86_64-ft_linux-gnu` would be read as GNU/Hurd. |
| Package versions | Read from the tarball names in `sources/` | One source of truth: the files present |
| Idempotent steps | `ln -sf`, stamps, `mountpoint` checks | Every script can be rerun safely |
| Init system | SysVinit and shell boot scripts | Simple, readable boot sequence; runlevels 3 (text) and services in `/etc/rc.d` |
| Device manager | udev built standalone from the systemd sources | Maintained implementation of udev, without the rest of systemd |
| `/etc/fstab` | `UUID=` | Device names differ between the build host (`/dev/loopXpN`) and the VM (`/dev/sdaN`) |
| Kernel `root=` | `root=PARTUUID=` | Works without an initramfs |
| Kernel config | `defconfig` + required options + VM drivers built in (`=y`), checked after `olddefconfig` | Unattended, reproducible, boots without an initramfs |
| Kernel sources | Kept in `/usr/src/kernel-6.16.1`, with `.config` and `/lib/modules/*/build` links | Required by the subject; ready for building kernel modules |
| GRUB | `search --fs-uuid` on `/boot` | Separate `/boot` partition |
| Network naming | `net.ifnames=0` → `eth0` | Predictable name in any VM |
| Time zone | `LFS_TZ` variable | Unattended build |
| Stripping | Library names resolved with `readlink` | A wrong name could break the system |
| SSH | `PermitRootLogin no`, regular user `lmilando` | Safer remote access |
| Mesa | `svga,softpipe`, no Vulkan, no Wayland, no LLVM | VirtualBox VMSVGA, with a software fallback; avoids building LLVM |
| Xorg-Server | `suid_wrapper=true` + `Xwrapper.config`, no elogind | Lets a console user run `startx` without elogind and PAM |
| GObject Introspection | Not built | Only needed for language bindings |
| gdk-pixbuf | PNG and the "others" loaders, no JPEG/TIFF | Avoids CMake and NASM for libjpeg-turbo |
| GTK 3 | X11 backend only | Xorg session only |
| Icon theme | lxde-icon-theme (`nuoveXT2`, PNG) | SVG themes need librsvg, hence Rust |
| Xfce components | Without thunar-volman and xfce4-power-manager | Need libgudev, UPower and polkit; not useful in a VM |
| Session | `startx` from `~/.bash_profile` on tty1, optional autologin | Graphical session at login; SSH and other consoles stay in text mode |

## Instructions

### Requirements

- An x86_64 Linux host with `sudo`, about 50 GB of free disk space and several hours of CPU time.
- The host tools checked by `05_versions_check.sh`. On RHEL-like hosts, `texinfo` comes from the CRB repository:
  ```bash
  sudo dnf config-manager --set-enabled crb && sudo dnf install texinfo
  ```
- `gdisk` (for `sgdisk`) if the image has to be resized.
- **VirtualBox** to boot the result.

All commands below are run from `host/` unless stated otherwise.

### 1. Host preparation

```bash
./05_versions_check.sh
./00_create_disk.sh
./01_loop_disk.sh
./02_parted_disk.sh
./03_format_partitions.sh
./07_mounting.sh
./08_get_sources.sh
./09_creating_limited_dir_layout.sh
./10_adding_ft_linux_user.sh
```

Check is not in the main download list, so fetch it manually:

```bash
wget -P /mnt/ft_linux/sources \
  https://github.com/libcheck/check/releases/download/0.15.2/check-0.15.2.tar.gz
```

### 2. Cross toolchain and temporary tools (as `ft_linux`)

```bash
su - ft_linux
/path/to/toolchain/10_cross_toolchain.sh
/path/to/toolchain/11_temp_tools.sh
```

These scripts re-execute themselves under `env -i` with a minimal environment, so no host setting can leak into the build.

### 3. Chroot and additional temporary tools

```bash
./20_chown_root.sh                        # once; ft_linux must not build after this
./21_mount_vfs.sh                         # at every session
./22_enter_chroot.sh 30_chroot_tools.sh
./23_umount_vfs.sh
./24_backup_temp_tools.sh                 # recommended checkpoint
```

### 4. Base system

```bash
./21_mount_vfs.sh
./22_enter_chroot.sh 40_ch8_lot1.sh
./22_enter_chroot.sh 41_ch8_lot2.sh
./22_enter_chroot.sh                      # interactive shell, then: passwd root
./22_enter_chroot.sh 42_ch8_lot3.sh
./22_enter_chroot.sh 43_ch8_lot4.sh
```

### 5. Configuration, boot and kernel sources

Review `chroot/ft_config.sh` first, then run:

```bash
./22_enter_chroot.sh 50_ch9_config.sh
./22_enter_chroot.sh 51_ch10_boot.sh
./22_enter_chroot.sh 52_kernel_sources.sh   # /usr/src/kernel-6.16.1
```

### 6. Network and SSH

```bash
./70_get_blfs_sources.sh blfs/10_net.list
./22_enter_chroot.sh 70_blfs_net.sh
./22_enter_chroot.sh                      # then: passwd lmilando
```

### 7. Xorg and Openbox (bonus)

```bash
./70_get_blfs_sources.sh blfs/20_x_libs.list   && ./22_enter_chroot.sh 71_blfs_x_libs.sh
./70_get_blfs_sources.sh blfs/30_x_server.list && ./22_enter_chroot.sh 72_blfs_x_server.sh
./70_get_blfs_sources.sh blfs/40_openbox.list  && ./22_enter_chroot.sh 73_blfs_openbox.sh
```

### 8. Xfce 4.20 (bonus)

```bash
./70_get_blfs_sources.sh blfs/50_gtk.list  && ./22_enter_chroot.sh 74_blfs_gtk.sh
./70_get_blfs_sources.sh blfs/60_xfce.list && ./22_enter_chroot.sh 75_blfs_xfce.sh
```

The graphical session is configured in `chroot/ft_config.sh`:

```bash
XKB_LAYOUT="fr"        # keyboard layout under X
X_SESSION="xfce"       # session started by startx: xfce or openbox
ICON_THEME="nuoveXT2"  # PNG icon theme from lxde-icon-theme
X_AUTOSTART=1          # run startx after login on tty1
AUTOLOGIN_USER=""      # e.g. "lmilando" to skip the login prompt on tty1
```

The session (`75.18`) and autostart (`73.11`) steps are reapplied on every run, so a change in `ft_config.sh` only needs the corresponding script to be run again. Nothing is recompiled.

### 9. Boot in VirtualBox

```bash
./23_umount_vfs.sh
./99_umount.sh                            # disk.raw must be detached first
./60_virtualbox_vm.sh                     # first run: convert, create and start
REFRESH=1 ./60_virtualbox_vm.sh           # after more work in the chroot
```

The VM uses BIOS firmware, a SATA AHCI disk, an Intel PRO/1000 NIC in NAT mode (10.0.2.15, gateway 10.0.2.2, DNS 10.0.2.3), the VMSVGA graphics controller, and forwards host port 2222 to guest port 22.

- VirtualBox works on `ft_linux.vdi`, a converted copy of `disk.raw`. `REFRESH=1` reconverts it and asks for confirmation, because changes made inside the VM are lost.
- If VirtualBox reports `VERR_VMX_IN_VMX_ROOT_MODE`, KVM is holding VT-x. The script unloads the `kvm` modules and retries. To fix this permanently on kernels ≥ 6.12 while keeping KVM usable:
  ```bash
  sudo grubby --update-kernel=ALL --args="kvm.enable_virt_at_load=0" && sudo reboot
  ```

### 10. Use the system

- **Login:** a text login prompt appears on tty1. With `X_AUTOSTART=1`, logging in there starts the X session (Xfce by default). Leaving the session returns to the shell. `Ctrl+Alt+F2`…`F6` are text consoles, and SSH logins are always text.
- **SSH from the host:** `ssh -p 2222 lmilando@localhost`
- **Start X by hand:** `startx`. To log session messages: `startx &> ~/.x-session-errors`
- **Boot to console only:** remove the autostart block from the user's (and root's) `~/.bash_profile`:
  ```bash
  sed -i '/^# >>> ft_linux startx/,/^# <<< ft_linux startx/d' ~/.bash_profile
  ```
  To restore it, set `X_AUTOSTART=1` and rerun `73_blfs_openbox.sh` in the chroot, or add the block back by hand:
  ```bash
  cat >> ~/.bash_profile << "EOF"
  # >>> ft_linux startx
  if [ -z "$DISPLAY" ] && [ "$(tty)" = /dev/tty1 ]; then
      startx
  fi
  # <<< ft_linux startx
  EOF
  ```
  If autologin is enabled, also remove `--autologin <user>` from the `tty1` line of `/etc/inittab`.
- **Shutdown:** without elogind and polkit, use `shutdown -h now` (or `reboot`) as root; Xfce's "Log Out" works.
- **Download and install software:** the system can download sources and build them, as required for the evaluation:
  ```bash
  cd /tmp
  wget https://ftp.gnu.org/gnu/hello/hello-2.12.2.tar.gz
  tar xf hello-2.12.2.tar.gz && cd hello-2.12.2
  ./configure --prefix=/usr/local && make && make install
  hello
  ```
  There is no package manager: `make uninstall` (or `ninja uninstall`) from the same build directory removes such a package.

### 11. Check the subject's requirements

Inside the VM, **as root** (reading the boot sector needs it):

```bash
bash /sources/ft_scripts/80_check_ft_linux.sh            # PASS / FAIL for each requirement
VERBOSE=1 bash /sources/ft_scripts/80_check_ft_linux.sh  # with versions, lsblk, services
```

It checks:
- the 67 required packages, each through its characteristic programs, libraries or files;
- the kernel: release ending in `-lmilando`, binary `/boot/vmlinuz-6.16.1-lmilando`, sources in `/usr/src/kernel-6.16.1`;
- root, `/boot` and swap on three distinct partitions;
- the hostname `lmilando`;
- SysVinit as PID 1, with its runlevels and boot scripts;
- GRUB installed, present in the boot sector and pointing to the running kernel;
- udev running as device manager and module loader.

The exit code is 0 when everything passes.

### Submission

As required by the subject, the virtual machine is not pushed. Only a checksum of its disk image is:

```bash
# VM shut down cleanly first
cp --sparse=always ft_linux.vdi ft_linux_submitted.vdi
shasum < ft_linux_submitted.vdi > ../disk.sha1
```

`ft_linux_submitted.vdi` is kept aside and **never booted**: every boot writes to the disk (logs, timestamps) and would change its checksum. The evaluation uses a copy of it, or a VirtualBox snapshot.

### Options

Options are environment variables, set on the host. `22_enter_chroot.sh` forwards them into the chroot.

| Variable | Default | Effect |
|----------|---------|--------|
| `TESTS` | `critical` | `critical`: test suites of the core toolchain (glibc, binutils, gmp, mpfr, mpc, gcc). `all`: every test suite. `none`: no tests. |
| `LFS_TZ` | `Europe/Paris` | Time zone |
| `FULL_LOCALES` | `0` | `1` installs every glibc locale |
| `GROFF_PAGE` | `A4` | Paper size for Groff |
| `SKIP_STRIP` | `0` | `1` skips stripping debug symbols |
| `LFS_VENDOR` | `ftlinux` | Vendor field of the cross triplet, used to remove the cross toolchain at cleanup |
| `VM_MEM`, `VM_CPUS` | `4096`, `4` | VirtualBox VM size (`60_virtualbox_vm.sh`) |
| `HEADLESS` | `0` | `1` starts the VM without a window |

Example: `TESTS=none ./22_enter_chroot.sh 41_ch8_lot2.sh`

### Resuming after a failure

When a step fails, the script prints the end of its log and stops. Fix the problem and rerun the same script. To redo a step that already succeeded, delete its stamp:

```bash
rm /mnt/ft_linux/sources/.stamps/10.03-kernel
```

| What | Path (on the host) |
|------|--------------------|
| Stamps | `/mnt/ft_linux/sources/.stamps/` |
| Build logs | `/mnt/ft_linux/sources/logs/<step>.log` |
| Test failures | `/mnt/ft_linux/sources/logs/tests-summary.txt` |
| GCC test summary | `/mnt/ft_linux/sources/logs/gcc-test-summary.txt` |
| Step durations | `/mnt/ft_linux/sources/logs/durations.txt` |

### Growing the disk image

Root is the last partition, so it can grow in place. Run this with everything unmounted:

```bash
./99_umount.sh
cp --sparse=always disk.raw disk.raw.bak
truncate -s 40G disk.raw
./01_loop_disk.sh && LOOP=$(cat .loopdev)
sudo sgdisk -e "$LOOP"
sudo parted "$LOOP" --script resizepart 4 100%
sudo partprobe "$LOOP"
sudo e2fsck -f "${LOOP}p4" && sudo resize2fs "${LOOP}p4"
```

### Roadmap

- [x] Base system: toolchain, temporary system, all required packages, configuration, kernel, GRUB
- [x] Kernel sources in `/usr/src/kernel-6.16.1`; all subject checks pass (`80_check_ft_linux.sh`)
- [x] Networking: make-ca, curl, wget, OpenSSH
- [x] Graphics: Xorg (Mesa svga/softpipe), Openbox, GTK 3 and the Xfce 4.20 desktop, `startx` at login
- [ ] `/etc/os-release` (the chroot safety check relies on it being absent, so it must change first)
- [ ] elogind and Linux-PAM, to run Xorg without the setuid wrapper and enable shutdown from Xfce
- [ ] Rust, librsvg and adwaita-icon-theme for complete SVG icons; a graphical login manager (LightDM)

## Resources

### Documentation

- [Linux From Scratch 12.4 (System V)](https://www.linuxfromscratch.org/lfs/view/stable/) — "The Bible" of the subject: build instructions for the toolchain and the base system
- [Beyond Linux From Scratch 12.4 (System V)](https://www.linuxfromscratch.org/blfs/view/12.4/) — build instructions for make-ca, curl, wget, OpenSSH, Xorg, Openbox, GTK and Xfce
- [LFS 12.4 — Package Management](https://www.linuxfromscratch.org/lfs/view/stable/chapter08/pkgmgt.html) — how packages can be tracked and removed without a package manager
- [LFS package mirrors](https://www.linuxfromscratch.org/mirrors.html#files) — archives that disappeared upstream
- [LFS FAQ](https://www.linuxfromscratch.org/faq/) and [LFS hints](https://www.linuxfromscratch.org/hints/)
- [Filesystem Hierarchy Standard](https://refspecs.linuxfoundation.org/fhs.shtml) — the directory layout the subject refers to
- [GNU Autoconf — canonical system names](https://www.gnu.org/software/autoconf/manual/autoconf.html#Canonicalizing) — how triplets such as `x86_64-ftlinux-linux-gnu` are parsed
- [GNU GRUB manual](https://www.gnu.org/software/grub/manual/grub/) — BIOS boot on GPT and the `bios_grub` partition
- [Linux kernel documentation](https://docs.kernel.org/) — `devtmpfs`, DRM, virtio
- [Mesa documentation](https://docs.mesa3d.org/) — Gallium drivers (svga, softpipe)
- [Openbox wiki](http://openbox.org/help/Main_Page) — configuration, menus, autostart
- [Xfce documentation](https://docs.xfce.org/) — components of the Xfce desktop
- [VirtualBox manual — VBoxManage](https://www.virtualbox.org/manual/ch08.html) — creating and configuring the VM from the command line
- `man` pages: `losetup(8)`, `parted(8)`, `sgdisk(8)`, `resize2fs(8)`, `chroot(1)`, `inittab(5)`, `agetty(8)`, `fstab(5)`, `startx(1)`, `Xwrapper.config(5)`

### Use of AI

an LLM was used as a teaching and research tool:

- explaining concepts (cross toolchains, boot process, X stack, package management) and comparing technical options;
- helping find commands and reviewing my scripts;
- helping diagnose build and boot failures from their logs;
- translating README.md into English.

All scripts were run, tested and corrected on my machine. Design decisions and the validation of the system are mine.
