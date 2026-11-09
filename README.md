*This project has been created as part of the 42 curriculum by lmilando.*

# ft_linux

## Description

**ft_linux** is about building a complete GNU/Linux distribution from source code, without relying on an existing distribution's packages. The system is built by following the **Linux From Scratch (LFS)** book, made bootable on its own, and then extended with **Beyond Linux From Scratch (BLFS)** packages: networking tools, an SSH server, and a graphical environment (Xorg + Openbox).

The goal is to understand what a Linux system is actually made of and how its pieces fit together: how a cross toolchain is bootstrapped, why the C library and compiler are built several times, how the kernel, udev, the init scripts and GRUB cooperate at boot, and how a graphical stack is assembled from the kernel DRM driver up to the window manager.

### Overview

| | |
|---|---|
| Books | LFS 12.4 and BLFS 12.4, System V editions |
| Architecture | x86_64, BIOS boot (GRUB `i386-pc`) |
| Disk | One GPT disk image (`disk.raw`, 40 GB) attached to a loop device |
| Init system | SysVinit + LFS-Bootscripts + BLFS bootscripts |
| Kernel | Linux 6.16.1, release string `6.16.1-lmilando` |
| Hostname | `lmilando` |
| Network / remote access | static IPv4, curl, wget, OpenSSH (`sshd` at boot) |
| Graphics | Xorg-Server 21.1 + Mesa (svga, softpipe) + Openbox 3.6 |
| Hypervisor | VirtualBox (BIOS, SATA AHCI, Intel PRO/1000, VMSVGA) |
| Build host | RPM-based distribution (RHEL / Rocky / Alma / Fedora) |

Every step of the books is turned into a shell script. Long builds are **resumable**: each finished step leaves a stamp. After a failure, you fix the cause and rerun the same script, which skips what is done and restarts the failed package from a fresh copy of its sources.

### Features

- The whole LFS 12.4 build is scripted, from creating the disk image to installing GRUB.
- All packages required by the subject, including **Check**, which was removed from LFS 12.4 and is built here with the LFS 12.3 instructions.
- BLFS additions: CA certificates (make-ca), curl, wget, OpenSSH with its boot script, Xorg, and the Openbox window manager. `startx` runs automatically after login on tty1.
- Each build step runs in its own `bash` with `set -euo pipefail`, has its own log, and is stamped when it succeeds.
- Test suites are configurable. They never block the build, and failures are collected into a single summary.
- Safety checks protect the host. Toolchain builds refuse to run as root, chroot scripts refuse to run outside the chroot, and destructive host scripts check that `$LFS` is valid and mounted.
- One script creates and starts the VirtualBox VM. It converts the raw image and, if needed, unloads KVM, which otherwise blocks VirtualBox.

### Repository layout

```
.
├── README.md
├── host_preparation_scripts/      # run on the host, as a normal user (they call sudo)
│   ├── env.sh                     # shared variables: LFS, LOOP, need_loop()
│   ├── 00_create_disk.sh          # sparse disk.raw
│   ├── 01_loop_disk.sh            # attach disk.raw to a loop device (.loopdev)
│   ├── 02_parted_disk.sh          # GPT: bios_grub / boot / swap / root
│   ├── 03_format_partitions.sh    # ext4 + swap, with labels
│   ├── 04_show_partitions.sh
│   ├── 05_versions_check.sh       # LFS host requirements (book 2.2)
│   ├── 07_mounting.sh             # mount root and /boot on /mnt/ft_linux
│   ├── 08_get_sources.sh          # LFS wget-list + md5sums, with mirror fallback
│   ├── 09_creating_limited_dir_layout.sh   # LFS 4.2
│   ├── 10_adding_ft_linux_user.sh # LFS 4.3
│   ├── 20_chown_root.sh           # LFS 7.2
│   ├── 21_mount_vfs.sh            # LFS 7.3 (every session)
│   ├── 22_enter_chroot.sh         # LFS 7.4: interactive shell, or run a chroot/ script
│   ├── 23_umount_vfs.sh
│   ├── 24_backup_temp_tools.sh    # LFS 7.13.2
│   ├── 25_restore_temp_tools.sh   # LFS 7.13.3
│   ├── 60_virtualbox_vm.sh        # create / refresh / start the VirtualBox VM
│   ├── 70_get_blfs_sources.sh     # download a BLFS batch and check MD5 sums
│   ├── 99_umount.sh               # unmount everything, detach the loop device
│   ├── blfs/                      # BLFS source lists: "<md5>  <url>" per line
│   │   ├── 10_net.list
│   │   ├── 20_x_libs.list
│   │   ├── 30_x_server.list
│   │   └── 40_openbox.list
│   └── chroot/                    # copied to /sources/ft_scripts, run INSIDE the chroot
│       ├── chroot_lib.sh          # stamps, logs, test helper
│       ├── ft_config.sh           # hostname, network, keymaps, kernel, X autostart
│       ├── 30_chroot_tools.sh     # LFS 7.5 - 7.13.1
│       ├── 40_ch8_lot1.sh         # LFS 8.3  Man-pages -> 8.19 Pkgconf
│       ├── 41_ch8_lot2.sh         # LFS 8.20 Binutils  -> 8.36 Bash
│       ├── 42_ch8_lot3.sh         # LFS 8.37 Libtool   -> 8.57 Meson
│       ├── 43_ch8_lot4.sh         # LFS 8.58 Kmod      -> 8.85 Cleanup (+ Check)
│       ├── 50_ch9_config.sh       # LFS chapter 9
│       ├── 51_ch10_boot.sh        # LFS chapter 10: fstab, kernel, GRUB
│       ├── 70_blfs_net.sh         # BLFS: make-ca, curl, wget, OpenSSH
│       ├── 71_blfs_x_libs.sh      # BLFS: Xorg libraries, XCB, libdrm, Python modules
│       ├── 72_blfs_x_server.sh    # BLFS: Mesa, Xorg apps/fonts, Xorg-Server, input, xterm
│       └── 73_blfs_openbox.sh     # BLFS: GLib, Cairo, Pango, Openbox, X autostart
└── temp_tools_build_scripts/      # run on the host as the ft_linux user
    ├── build_env.sh               # clean build environment (LFS 4.4)
    ├── build_lib.sh               # stamps and logs for chapters 5-6
    ├── 09_reset_lfs.sh            # wipe $LFS back to the end of chapter 4 (uses sudo)
    ├── 10_cross_toolchain.sh      # LFS chapter 5
    └── 11_temp_tools.sh           # LFS chapter 6
```

`22_enter_chroot.sh` copies **only** `chroot/*.sh` into the chroot, so every script that runs inside it, plus `ft_config.sh`, must live in `chroot/`.

Build artifacts stay out of version control:

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

On the host, `$LFS` is `/mnt/ft_linux`. The loop device is never hard-coded: `01_loop_disk.sh` stores it in `.loopdev`, and `env.sh` reads it back.

### Technical choices

Every package is built with the books' commands. These are the deliberate differences:

| Area | Book | This project | Reason |
|------|------|--------------|--------|
| Cross triplet | `x86_64-lfs-linux-gnu` | `x86_64-ftlinux-linux-gnu` | Personal vendor field. The OS part must stay `linux-gnu`: `x86_64-ft_linux-gnu` is read as GNU/Hurd. |
| Package versions | Written in the commands | Read from the tarball names | `sources/` is the single source of truth |
| Symlinks | `ln -sv` | `ln -sfv` | Steps can be rerun |
| Check | Removed in LFS 12.4 | Built after Coreutils (12.3 instructions) | Required by the subject |
| Eudev (subject list) | Not in LFS 12.4 | Udev from systemd + `udev-lfs` tarball | The equivalent the book supports |
| Pkg-config (subject list) | Pkgconf | Pkgconf with its `pkg-config` link | As in the book |
| Time zone | Interactive `tzselect` | `LFS_TZ` variable | Unattended build |
| Stripping (8.84) | Library names written out | Names resolved with `readlink` | A wrong name can break the system |
| Network naming (9.4) | Udev rules or `net.ifnames=0` | `net.ifnames=0` → `eth0` | Persistent rules are unreliable in VMs |
| `/etc/fstab` | `/dev/sdXN` | `UUID=` | Device names differ between host and VM |
| Kernel `root=` | `/dev/sda2` | `root=PARTUUID=` | The book's alternative; no initramfs needed |
| Kernel config | `make menuconfig` | `defconfig` + the book's options + VM drivers `=y`, checked after `olddefconfig` | Unattended and reproducible |
| GRUB | `set root=(hd0,2)` | `search --fs-uuid` on `/boot` | Separate `/boot` partition |
| make-ca (BLFS) | Runs with the system DNS | Uses the host `resolv.conf` during that step | In the chroot, `/etc/resolv.conf` already holds the VM's DNS (10.0.2.3) |
| SSH login | `PermitRootLogin no` | Same, plus a regular user `lmilando` | Something must be able to log in |
| `/etc/profile.d` | Created by BLFS "Bash Shell Startup Files" | Created and sourced from `/etc/profile` | Needed for `xorg.sh` |
| Mesa | All Gallium/Vulkan drivers, LLVM recommended | `svga,softpipe`, no Vulkan, no Wayland, no LLVM | VirtualBox VMSVGA; avoids building LLVM |
| Xorg-Server | `systemd_logind=true` (elogind) | `systemd_logind=false`, `suid_wrapper=true`, `Xwrapper.config` | No elogind/PAM; classic way to let a console user run `startx` |
| GLib, Pango | Introspection enabled, man pages | No GObject Introspection, no man pages | Not needed by Openbox; avoids extra dependencies |
| HarfBuzz, libxml2 | Graphite2, ICU | Without them | Optional; not installed |
| Openbox dependencies | Pango | Pango **+ libxml2** | Openbox's configure requires libxml2 |
| Session | `startx` by hand | `startx` from `~/.bash_profile` on tty1, optional autologin | Graphical session at boot; SSH and other consoles unaffected |

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
| `wget`, `md5sum` | `08`, `70` | Download sources and check them against the books' MD5 sums |
| `su`, `env -i` | `10`, `11` | Build chapters 5–6 as the unprivileged `ft_linux` user, in an empty environment |
| `chroot` | `22` | Runs a shell or a script with `$LFS` as `/`, so packages are built against the new system |
| `tar`, `patch`, `sed` | every build step | Unpack sources, apply the books' patches and source fixes |
| `./configure`, `make` | most packages | Autotools build: detect the system, compile, install |
| `meson`, `ninja` | newer packages (Kmod, udev, Mesa, Xorg-Server, GLib…) | Meson configures the build, Ninja runs it |
| `pip3 wheel` / `pip3 install` | Python modules | Build and install Python packages offline from their source tarballs |
| `ldconfig` | after libraries | Refreshes the dynamic linker cache |
| `strip`, `objcopy` | 8.84 | Remove debug symbols to save space, keeping separate debug info for core libraries |
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
| Boot scripts | LFS-Bootscripts, BLFS bootscripts | `/etc/rc.d/init.d/*`: mount filesystems, start udev, syslog, network, `sshd`… |
| Device manager | udev (from systemd) | Creates device nodes and loads modules as the kernel reports hardware |
| C library | Glibc | The C runtime and the dynamic loader (`/lib64/ld-linux-x86-64.so.2`) every program uses |
| Shell and base tools | Bash, Coreutils, Util-linux, Grep, Sed… | The command line; `agetty` and `mount` come from Util-linux |
| Accounts | Shadow | `useradd`, `passwd`, `/etc/shadow`, `login` rules |
| Logging | Sysklogd | Writes kernel and daemon messages to `/var/log/*.log` |
| Network | IPRoute2, Inetutils | `ip` configures `eth0` from `/etc/sysconfig/ifconfig.eth0`; `ping`, `hostname`… |
| Certificates | make-ca, p11-kit | Mozilla's CA store in `/etc/ssl/certs`, used by curl, wget and OpenSSL |
| Downloads | curl, wget | HTTP(S) clients |
| Remote access | OpenSSH (`sshd`) | SSH server started at boot; root login disabled |
| Compiler toolchain | GCC, Binutils, Make, Autotools, Meson | Build further software directly on the new system |
| Display server | Xorg-Server (+ `Xorg.wrap`) | Draws on screen through the kernel DRM driver (`modesetting` + vmwgfx) and reads input via libinput |
| OpenGL | Mesa (`svga`, `softpipe`) | 3D through VirtualBox's VMSVGA, with a software fallback |
| Session start | xinit (`startx`) | Starts the X server and runs `~/.xinitrc` |
| Window manager | Openbox | Draws window frames, handles focus and moving windows, right-click root menu |
| Terminal | xterm | Terminal emulator under X (`x-terminal-emulator` points to it) |
| Fonts | Xorg Fonts, DejaVu, Fontconfig, FreeType | Font files, discovery and rendering |
| Text rendering | Pango, Cairo, HarfBuzz, FriBidi | Layout and drawing of text in Openbox menus and titles |

## Instructions

### Requirements

- An x86_64 Linux host with `sudo`, about 50 GB of free disk space and several hours of CPU time.
- The host tools checked by `05_versions_check.sh`. On RHEL-like hosts, `texinfo` comes from the CRB repository:
  ```bash
  sudo dnf config-manager --set-enabled crb && sudo dnf install texinfo
  ```
- `gdisk` (for `sgdisk`) if the image has to be resized.
- **VirtualBox** to boot the result (the evaluation hypervisor).

All commands below are run from `host_preparation_scripts/` unless stated otherwise.

### 1. Host preparation — LFS chapters 2 to 4

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

Check is not in the LFS 12.4 download list, so fetch it manually:

```bash
wget -P /mnt/ft_linux/sources \
  https://github.com/libcheck/check/releases/download/0.15.2/check-0.15.2.tar.gz
```

### 2. Cross toolchain and temporary tools (as `ft_linux`) — chapters 5 and 6

```bash
su - ft_linux
/path/to/temp_tools_build_scripts/10_cross_toolchain.sh
/path/to/temp_tools_build_scripts/11_temp_tools.sh
```

These scripts re-execute themselves under `env -i` with the book's environment, so no host setting can leak into the build.

### 3. Chroot and additional temporary tools — chapter 7

```bash
./20_chown_root.sh                        # once; ft_linux must not build after this
./21_mount_vfs.sh                         # at every session
./22_enter_chroot.sh 30_chroot_tools.sh
./23_umount_vfs.sh
./24_backup_temp_tools.sh                 # recommended checkpoint
```

### 4. Basic system software — chapter 8

```bash
./21_mount_vfs.sh
./22_enter_chroot.sh 40_ch8_lot1.sh
./22_enter_chroot.sh 41_ch8_lot2.sh
./22_enter_chroot.sh                      # interactive shell, then: passwd root
./22_enter_chroot.sh 42_ch8_lot3.sh
./22_enter_chroot.sh 43_ch8_lot4.sh
```

### 5. Configuration and boot — chapters 9 and 10

Review `chroot/ft_config.sh` first, then run:

```bash
./22_enter_chroot.sh 50_ch9_config.sh
./22_enter_chroot.sh 51_ch10_boot.sh
```

### 6. BLFS: network and SSH

```bash
./70_get_blfs_sources.sh blfs/10_net.list
./22_enter_chroot.sh 70_blfs_net.sh
./22_enter_chroot.sh                      # then: passwd lmilando
```

### 7. BLFS: Xorg and Openbox

```bash
./70_get_blfs_sources.sh blfs/20_x_libs.list   && ./22_enter_chroot.sh 71_blfs_x_libs.sh
./70_get_blfs_sources.sh blfs/30_x_server.list && ./22_enter_chroot.sh 72_blfs_x_server.sh
./70_get_blfs_sources.sh blfs/40_openbox.list  && ./22_enter_chroot.sh 73_blfs_openbox.sh
```

The graphical session is configured in `chroot/ft_config.sh`:

```bash
XKB_LAYOUT="fr"       # keyboard layout under X
X_AUTOSTART=1         # run startx after login on tty1
AUTOLOGIN_USER=""     # e.g. "lmilando" to skip the login prompt on tty1
```

The `73.11-x-autostart` step is reapplied on every run, so a change in `ft_config.sh` only needs `./22_enter_chroot.sh 73_blfs_openbox.sh`.

### 8. Boot in VirtualBox

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

### 9. Check the result

On the VM console:

```bash
uname -r                     # 6.16.1-lmilando
hostname                     # lmilando
ip addr show eth0            # 10.0.2.15/24
ls /etc/rc.d/rc3.d/          # S..sshd among the services
less /var/log/boot.log       # every boot script should be [ OK ]
```

Logging in on tty1 starts Openbox. Right-click the desktop for the menu (Terminal, Reconfigure, Exit). `Alt+F2` gives a text console.

From the host:

```bash
ssh -p 2222 lmilando@localhost
```

### Options

Options are environment variables, set on the host. `22_enter_chroot.sh` forwards them through `env -i`.

| Variable | Default | Effect |
|----------|---------|--------|
| `TESTS` | `critical` | `critical`: tests the book calls critical (glibc, binutils, gmp, mpfr, mpc, gcc). `all`: every test. `none`: no tests. |
| `LFS_TZ` | `Europe/Paris` | Time zone (8.5) |
| `FULL_LOCALES` | `0` | `1` installs every glibc locale |
| `GROFF_PAGE` | `A4` | Paper size for Groff |
| `SKIP_STRIP` | `0` | `1` skips the optional stripping (8.84) |
| `LFS_VENDOR` | `ftlinux` | Vendor field of the cross triplet, used by the cleanup (8.85) |
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
| Durations (SBU) | `/mnt/ft_linux/sources/logs/durations.txt` |

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

- [x] LFS chapters 2 to 10: toolchain, temporary system, basic system, configuration, kernel, GRUB
- [x] BLFS: make-ca, curl, wget, OpenSSH
- [x] BLFS: Xorg (Mesa svga/softpipe) and Openbox, `startx` at login
- [ ] LFS chapter 11: `/etc/os-release`, `/etc/lsb-release` (the chroot safety check relies on `os-release` being absent, so it must change first)
- [ ] BLFS: dbus, elogind and Linux-PAM, to run Xorg without the setuid wrapper
- [ ] BLFS: GTK3 stack and the Xfce 4.20 desktop

## Resources

### Documentation

- [Linux From Scratch 12.4 (System V)](https://www.linuxfromscratch.org/lfs/view/stable/) — the reference followed for every package
- [Beyond Linux From Scratch 12.4 (System V)](https://www.linuxfromscratch.org/blfs/view/12.4/) — make-ca, curl, wget, OpenSSH, Xorg, Openbox
- [BLFS 12.4 — Graphical Environments](https://linuxfromscratch.org/blfs/view/12.4/x/x.html) — the Xorg chapter followed in order
- [LFS 12.3 — Check-0.15.2](https://www.linuxfromscratch.org/lfs/view/12.3/chapter08/check.html) — instructions for Check, removed in 12.4
- [LFS package mirrors](https://www.linuxfromscratch.org/mirrors.html#files) — archives that disappeared upstream
- [LFS FAQ](https://www.linuxfromscratch.org/faq/) and [LFS hints](https://www.linuxfromscratch.org/hints/)
- [GNU Autoconf — canonical system names](https://www.gnu.org/software/autoconf/manual/autoconf.html#Canonicalizing) — how triplets such as `x86_64-ftlinux-linux-gnu` are parsed
- [GNU GRUB manual](https://www.gnu.org/software/grub/manual/grub/) — BIOS boot on GPT and the `bios_grub` partition
- [Linux kernel documentation](https://docs.kernel.org/) — `devtmpfs`, DRM, virtio
- [Mesa documentation](https://docs.mesa3d.org/) — Gallium drivers (svga, softpipe)
- [Openbox wiki](http://openbox.org/help/Main_Page) — configuration, menus, autostart
- [VirtualBox manual — VBoxManage](https://www.virtualbox.org/manual/ch08.html) — creating and configuring the VM from the command line
- `man` pages: `losetup(8)`, `parted(8)`, `sgdisk(8)`, `resize2fs(8)`, `chroot(1)`, `inittab(5)`, `agetty(8)`, `fstab(5)`, `startx(1)`, `Xwrapper.config(5)`
