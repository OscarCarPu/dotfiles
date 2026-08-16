[⬅ Back to main README](../README.md)

# Bootstrap — from a blank disk to this exact system

Everything that has to happen **before** `install.sh` can do anything, and then
the exact order of the repo's own steps. `install.sh` assumes a booting Artix
with a user, a network and an AUR-capable toolchain; this file is how you get
there.

Split in two:

- [Part 1 — Prior actions](#part-1--prior-actions-blank-disk--booting-artix): manual, once per machine, from the ISO.
- [Part 2 — Execution](#part-2--execution-booting-artix--this-system): the repo's scripts, in order.
- [Part 3 — Manual leftovers](#part-3--manual-leftovers): what no script can do for you.

> **This machine is a special case.** It dual-boots and has **no bootloader of
> its own** — `grub`, `efibootmgr` and `os-prober` are not installed. It boots
> only because the neighbouring Arch install's GRUB finds
> `/boot/vmlinuz-linux` on the Artix root partition. On a fresh single-OS
> machine you **must** install a bootloader ([step 1.10](#110-bootloader)) or
> the disk will not boot.

---

## Part 1 — Prior actions (blank disk → booting Artix)

Boot the Artix **base/runit** ISO (not the graphical one — the desktop editions
ship dinit/s6 variants and a different service set).

Reference values below are what this machine actually runs. Change the disk
node, sizes and hostname; keep the rest identical or the repo's assumptions
break.

### 1.1 Network on the live ISO

```bash
# Wired: usually already up. Wi-Fi:
rfkill unblock wifi
connmanctl                      # the runit ISO ships connman
  > enable wifi
  > scan wifi
  > services                    # note the wifi_... id
  > agent on
  > connect wifi_xxxxxxxx
  > quit
ping -c2 artixlinux.org
```

### 1.2 Clock and keyboard

```bash
loadkeys es
```

### 1.3 Partitioning

Current layout on `/dev/nvme0n1` (1.9 TB), for reference:

| Partition | Size | FS | Label | Mount | What |
|---|---|---|---|---|---|
| `nvme0n1p1` | 930 G | ext4 | `artix_root` | `/` | Artix |
| `nvme0n1p2` | 1 G | vfat | — | *not mounted* | ESP (owned by the Arch install) |
| `nvme0n1p5` | 976 G | ext4 | — | — | the Arch install |

**There is no swap partition and no swap file** — 62 GB of RAM, and hibernation
is not used. Keep it that way unless the new machine has less memory.

For a single-OS machine, the minimum is an ESP plus a root partition:

```bash
fdisk /dev/nvme0n1
  g                     # GPT
  n  1  <enter>  +1G    # ESP
  t  1  uefi
  n  2  <enter>  <enter>   # root, rest of disk
  w

mkfs.fat -F32 /dev/nvme0n1p1
mkfs.ext4 -L artix_root /dev/nvme0n1p2
```

`artix_root` as the filesystem label matters: the `fstab` comment references it
and it is how you identify the partition from a rescue shell.

### 1.4 Mount and install the base system

```bash
mount /dev/nvme0n1p2 /mnt
mkdir -p /mnt/boot/efi
mount /dev/nvme0n1p1 /mnt/boot/efi     # single-OS machines only; see 1.10

basestrap /mnt base base-devel runit elogind-runit \
                linux linux-headers linux-firmware intel-ucode \
                mkinitcpio nano
```

`intel-ucode` is CPU-specific — swap for `amd-ucode` on AMD. `elogind-runit`
(not plain `elogind`) is what pulls the seat/session support the whole desktop
depends on: `loginctl poweroff`, polkit, Hyprland's DRM master.

### 1.5 fstab

```bash
fstabgen -U /mnt >> /mnt/etc/fstab
cat /mnt/etc/fstab
```

This machine's `/etc/fstab` has exactly **one** entry — the ESP is deliberately
absent because Arch owns it:

```
UUID=4bba3857-9a5e-4d6d-b533-bf6cd33db3a0	/	ext4	rw,relatime	0 1
```

On a single-OS machine you want the ESP line too (`fstabgen` adds it if it was
mounted in 1.4).

### 1.6 Chroot

```bash
artix-chroot /mnt bash
```

Everything from here to [1.12](#112-first-boot) runs inside the chroot.

### 1.7 Time, locale, keymap, hostname

```bash
ln -sf /usr/share/zoneinfo/Europe/Madrid /etc/localtime
hwclock --systohc

# /etc/locale.gen — uncomment exactly these two:
#   en_US.UTF-8 UTF-8
#   es_ES.UTF-8 UTF-8
locale-gen
echo 'LANG=es_ES.UTF-8'  > /etc/locale.conf
echo 'KEYMAP=es'         > /etc/vconsole.conf
echo 'artix-ocp'         > /etc/hostname
```

`/etc/hosts`:

```
127.0.0.1        localhost
::1              localhost
127.0.0.1 artix-ocp.localdomain artix-ocp
```

`KEYMAP=es` in `vconsole.conf` only covers the TTY. Hyprland's layout is set
separately in `hypr/hyprland.lua` (`kb_layout = "es"`), so both need to agree.

### 1.8 initramfs

Stock hooks are what this machine runs — no custom modules, no encryption:

```
MODULES=()
HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)
```

```bash
mkinitcpio -P
```

`kms` matters: it loads the DRM driver early. Without it Hyprland starts on a
software-rendered framebuffer.

### 1.9 Root password, user, sudo

```bash
passwd                                  # root

useradd -m -G wheel,audio,input,optical,storage,video ocp
passwd ocp
```

The groups above are the ones needed at first boot. `install.sh --system` adds
the rest (`docker`, `uucp`, `adbusers`, `realtime`, `android-sdk`) once their
packages exist — do not add them here, the groups do not exist yet.

Sudo for `wheel`:

```bash
pacman -S sudo
EDITOR=nano visudo         # uncomment: %wheel ALL=(ALL:ALL) ALL
```

### 1.10 Bootloader

**Skip only if another distro's GRUB on the same disk will pick this install
up** (this machine's situation — see the note at the top). In that case just
run `grub-mkconfig -o /boot/grub/grub.cfg` **from the other distro** with
`os-prober` installed and `GRUB_DISABLE_OS_PROBER=false`, and set the default
with `grub-set-default`.

Otherwise:

```bash
pacman -S grub efibootmgr os-prober
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Artix
grub-mkconfig -o /boot/grub/grub.cfg
```

### 1.11 Services at first boot

Only what is needed to reach a login and a network:

```bash
pacman -S networkmanager networkmanager-runit

ln -s /etc/runit/sv/NetworkManager /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/dbus           /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/elogind        /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/udevd          /etc/runit/runsvdir/default/
for n in 1 2 3 4 5 6; do
    ln -s "/etc/runit/sv/agetty-tty$n" /etc/runit/runsvdir/default/
done
```

`/etc/runit/runsvdir/current` is a symlink to `default` — always link into
`default`, never into `current`.

**Immediately remove the duplicate `logind` service.** `elogind-runit` ships
both `elogind` and `logind` (the latter a symlink to the former) and the
installer links both, so two supervisors race for the same daemon on every cold
boot:

```bash
rm -f /etc/runit/runsvdir/default/logind
```

> `install.sh --system` now does this too, so it is self-healing after a
> package update relinks it — but do it here so the very first boot is clean.

### 1.12 First boot

```bash
exit
umount -R /mnt
reboot
```

Log in as `ocp` on a TTY and bring the network up:

```bash
nmcli device wifi list --rescan yes
nmcli device wifi connect <SSID>
```

You now have what `install.sh` expects.

---

## Part 2 — Execution (booting Artix → this system)

Order matters. Each step depends on the previous one.

### 2.1 Arch repos (`[extra]`) and multilib (`[lib32]`)

The repo's `pacman.conf` enables `[lib32]` and pulls `[extra]` from
`/etc/pacman.d/mirrorlist-arch` — that file only exists once
`artix-archlinux-support` is installed, so it has to come **before**
`install.sh --system` links the config in:

```bash
sudo pacman -Sy --needed artix-archlinux-support artix-keyring artix-mirrorlist
sudo pacman-key --populate archlinux
```

### 2.2 Clone

```bash
sudo pacman -S --needed git
git clone https://github.com/OscarCarPu/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
```

HTTPS on purpose: the SSH remote (`git-ssh.lab-ocp.com`) needs a key and
`cloudflared`, neither of which exists yet. Switch the remote later.

### 2.3 Secrets

```bash
install -Dm600 configs/secrets.env.example ~/.config/dotfiles/secrets.env
$EDITOR ~/.config/dotfiles/secrets.env
```

`install.sh` creates this from the example if it is missing, but filling it in
first means the OrcaSlicer presets get their PrusaLink password on the first
pass instead of needing a second run. See
[`printing.md`](printing.md#prusalink-password).

### 2.4 Packages

```bash
bash install-packages.sh
```

Bootstraps `yay` if absent, then installs everything in
[`packages.md`](packages.md) plus the toolchains that do not come from pacman:
`uv tool` (pyright, ruff), `cargo` (espup, espflash), `go` (sqlc), and Claude
Code via its own installer.

Two steps in it will *skip with a warning* on a first run, by design:

- **`pyright`/`ruff`** if `uv` was installed in this same run and is not on
  `PATH` yet.
- **Android SDK** platforms/build-tools, which need the `android-sdk` group
  from step 2.6.

Both are picked up by the re-run in [2.8](#28-second-pass).

### 2.5 User symlinks

```bash
bash install.sh
```

Configs, per-file `~/.local/bin` scripts, user runit services, git credential
filters, the LibreWolf profile hook and the AutoFirma CA.

### 2.6 System symlinks

```bash
bash install.sh --system
```

`/etc` files, sudoers drop-ins, system runit services, the `logind` and
`elogind` fixes, group membership and a udev reload.

**Log out and back in** (or `newgrp`) so the new groups take effect — `docker`
and `android-sdk` do nothing until you do.

### 2.7 File sync

```bash
$EDITOR ~/.config/seafile-cli/credentials    # from configs/seafile-cli/credentials.example
chmod 600 ~/.config/seafile-cli/credentials
seafile-setup
```

Creates and syncs `~/edu`, `~/docs`, `~/downloads`, `~/media` (~26 GB — expect
hours on a first run). Details and gotchas in [`seafile.md`](seafile.md).

Do **not** reorganise those folders while the initial upload runs; the daemon
reverts local moves to match the in-progress server snapshot. Wait for
`seaf-cli status` to report `synchronized` on all four.

### 2.8 Second pass

```bash
bash install-packages.sh    # picks up pyright/ruff + Android SDK
```

### 2.9 Verify

```bash
bash install.sh --check
```

Reports every drift between the repo and the machine: undocumented packages,
unlinked configs, orphaned services, unsynced libraries, git repos with no
remote. A clean run means the machine matches the repo.

Then the hardware-specific checks from
[`system.md`](system.md#6-verifying-the-install) (evdi/DisplayLink, monitors,
audio services).

---

## Part 3 — Manual leftovers

Nothing in the repo can do these; they are the real cost of a rebuild.

| Thing | Where it lives | How to restore |
|---|---|---|
| **SSH key** | `~/.ssh/id_ed25519` | Not backed up anywhere by design. Generate a new one and add it in Gitea + GitHub. |
| **Git remote** | `.git/config` | `git remote set-url origin ssh://git@git-ssh.lab-ocp.com/ocp/dotfiles.git` once the key and `cloudflared` work |
| **`~/dev`** | Gitea + GitHub | Clone by hand — intentionally not synced |
| **PrusaLink password** | printer UI | Settings → Network → PrusaLink, into `secrets.env` |
| **Seafile password** | password manager | `~/.config/seafile-cli/credentials` |
| **LibreWolf profile** | Sync account | Sign in; `user.js` and the AutoFirma CA are handled by `install.sh` |
| **FNMT certificate** | `~/docs/personal/fnmt-cert/` | Comes back with Seafile; import into LibreWolf by hand |
| **App logins** | — | Obsidian, Steam, Discord, Spotify, Teams |
| **Monitor layout** | `hypr/hyprland.lua` | Matched by EDID serial. Different monitors ⇒ edit the `hl.monitor` blocks; the catch-all keeps unknown outputs off-screen instead of overlapping |
| **Bootloader default** | Arch's GRUB | `grub-set-default 'Artix Linux (on /dev/nvme0n1pX)'` from Arch |

### If the hardware is different

The repo assumes this laptop in four places. Grep before trusting a new
machine:

- `hypr/hyprland.lua` — monitors by EDID serial, `eDP-1` as the internal panel
- `hypr/scripts/setup_monitors_by_serial.sh` — same serials
- `hypr/scripts/brightness.sh` — `intel_backlight`
- `home/Makefile` — hardcoded `/home/ocp` paths

Also swap `intel-ucode` for `amd-ucode` in [1.4](#14-mount-and-install-the-base-system),
and drop the DisplayLink pieces (`displaylink` service, `evdi.conf`, the dock
udev rule) if there is no DisplayLink dock.
