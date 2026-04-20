[← Back to main README](../README.md)

# Migración Arch → Artix Linux + Hyprland + runit

Instalación en paralelo — usar ambos sistemas hasta que Artix esté perfecto.

---

## Fase 0: Preparar ANTES de instalar Artix

### Backups críticos

```bash
cp ~/.local/state/syncthing/config.xml ~/backup/syncthing-config.xml
cp ~/.config/rclone/rclone.conf ~/backup/rclone.conf
cp -r ~/.config/gh/ ~/backup/gh/
cp ~/.config/systemd/user/bt-spotify-switch.service ~/backup/
cp -r ~/.local/bin/ ~/backup/local-bin/
```

⚠️ `GROQ_API_KEY` está en texto plano en `~/.bashrc` — moverla a `~/.env` y hacer `source ~/.env` desde bashrc.

### Cambios en este repo (compatibilidad sin systemd)

**`hypr/scripts/audio_watcher.sh`** y **`hypr/scripts/refresh_audio.sh`:**

Cambiar:
```bash
systemctl --user restart wireplumber pipewire pipewire-pulse
```
Por:
```bash
pkill -x wireplumber; pkill -x pipewire-pulse; pkill -x pipewire
sleep 1
pipewire &
sleep 0.5
pipewire-pulse &
wireplumber &
```

**`hypr/scripts/shutdown.sh`:**
- `systemctl poweroff` → `poweroff`
- `systemctl reboot` → `reboot`
- `sudo systemctl poweroff` → `sudo poweroff`
- `sudo systemctl reboot` → `sudo reboot`

**`hypr/hyprland.conf`** — añadir al bloque `exec-once`:
```ini
exec-once = pipewire &
exec-once = pipewire-pulse &
exec-once = wireplumber &
exec-once = ~/.local/bin/bt-spotify-switch &
exec-once = runsvdir ~/.local/share/runit/sv &
```

---

## Fase 1: Instalar Artix (en partición separada)

**ISO:** Artix base con runit — https://artixlinux.org/download.php

```bash
# Desde el live ISO
loadkeys es

# Crear partición nueva para Artix (no tocar la de Arch)
# Ejemplo: /dev/nvme0n1p5 para /, compartir /dev/nvme0n1p2 (EFI)
mount /dev/nvme0n1p5 /mnt
mount --mkdir /dev/nvme0n1p2 /mnt/boot/efi

basestrap /mnt base base-devel runit elogind-runit linux linux-firmware

fstabgen -U /mnt >> /mnt/etc/fstab
artix-chroot /mnt

# Config base
ln -sf /usr/share/zoneinfo/Europe/Madrid /etc/localtime
hwclock --systohc
# Editar /etc/locale.gen → descomentar es_ES.UTF-8 y en_US.UTF-8
locale-gen
echo "LANG=es_ES.UTF-8" > /etc/locale.conf
echo "KEYMAP=es" > /etc/vconsole.conf
echo "artix-ocp" > /etc/hostname

# Bootloader (detectará ambos sistemas via os-prober)
pacman -S grub efibootmgr os-prober
grub-install --target=x86_64-efi --efi-directory=/boot/efi
grub-mkconfig -o /boot/grub/grub.cfg

# Usuario
useradd -mG wheel,video,audio,storage,optical,input ocp
passwd ocp
visudo  # descomentar %wheel ALL=(ALL:ALL) ALL
```

### Habilitar repos de Arch
```bash
pacman -S artix-archlinux-support
# Añadir a /etc/pacman.conf:
# [extra]
# Include = /etc/pacman.d/mirrorlist-arch
# [multilib]
# Include = /etc/pacman.d/mirrorlist-arch
pacman -Sy
```

---

## Fase 2: Post-install

### Servicios runit del sistema
```bash
sudo ln -s /etc/runit/sv/NetworkManager /run/runit/service/
sudo ln -s /etc/runit/sv/elogind /run/runit/service/
sudo ln -s /etc/runit/sv/bluetoothd /run/runit/service/
sudo ln -s /etc/runit/sv/lm_sensors /run/runit/service/

# Tiempo (reemplaza systemd-timesyncd)
sudo pacman -S chrony-runit
sudo ln -s /etc/runit/sv/chronyd /run/runit/service/
```

### Paquetes — Wayland + Hyprland
```bash
sudo pacman -S hyprland uwsm xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
               waybar swaync wofi wlogout wl-clipboard grim slurp swaybg \
               kitty chromium firefox
```

### Paquetes — Audio
```bash
sudo pacman -S pipewire pipewire-pulse pipewire-alsa wireplumber pavucontrol
```

### Paquetes — Hardware crítico (⚠️ DisplayLink para los 3 monitores)
```bash
# Instalar yay primero
sudo pacman -S git
git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si

yay -S displaylink evdi-dkms
sudo ln -s /etc/runit/sv/displaylink /run/runit/service/

yay -S nbfc-linux
sudo ln -s /etc/runit/sv/nbfc_service /run/runit/service/

sudo pacman -S intel-media-driver vulkan-intel intel-gpu-tools lib32-mesa lib32-vulkan-intel
```

### Paquetes — Networking
```bash
sudo pacman -S networkmanager network-manager-applet bluez bluez-utils blueman openssh syncthing rclone
```

### Paquetes — Dev stack
```bash
sudo pacman -S git github-cli go rustup nodejs npm pnpm \
               jdk-openjdk jdk11-openjdk jdk21-openjdk jre8-openjdk gradle \
               python-pipx uv direnv \
               docker docker-compose docker-buildx \
               libvirt qemu-full virt-manager \
               r gcc-fortran \
               fd fzf ripgrep jq tree htop ncdu socat \
               neovim tree-sitter-cli
```

### Paquetes — AUR
```bash
yay -S android-sdk android-sdk-build-tools android-sdk-cmdline-tools-latest \
       android-sdk-platform-tools android-tools android-udev \
       kotlin-language-server spotify ttf-nanum \
       autofirma-bin quarto-cli-bin rstudio-desktop-bin \
       openssl-1.1 woeusb debtap
```

### Paquetes — Multimedia / Producción
```bash
sudo pacman -S ardour supercollider sc3-plugins obs-studio audacity \
               darktable geeqie imv vlc \
               freecad prusa-slicer libreoffice-fresh \
               discord telegram-desktop obsidian evolution evolution-ews \
               gamemode steam wine mangohud lib32-mangohud lib32-gamemode \
               brightnessctl reflector pacman-contrib scrcpy imagemagick
# MuseScore: descargar AppImage desde musescore.org y poner en ~/.local/bin/
```

### Flatpak
```bash
sudo pacman -S flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install flathub com.stremio.Stremio
flatpak install flathub net.sonic_pi.SonicPi
```

### Fuentes
```bash
sudo pacman -S ttf-cascadia-code-nerd ttf-firacode-nerd
yay -S woff2-font-awesome ttf-nanum
```

### Toolchains no-pacman
```bash
# Rust + ESP32
rustup install stable
yay -S espup && espup install
cargo install espflash esp-generate ldproxy

# Haskell
curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh

# Bun
curl -fsSL https://bun.sh/install | bash

# uv tools
uv tool install apache-airflow-breeze
uv tool install prek
```

### Dotfiles y configuración
```bash
git clone <tu-repo> ~/.dotfiles
cd ~/.dotfiles && ./install.sh

# Restaurar configs con valor
mkdir -p ~/.local/state/syncthing ~/.config/rclone ~/.config/gh ~/.local/bin
cp ~/backup/syncthing-config.xml ~/.local/state/syncthing/config.xml
cp ~/backup/rclone.conf ~/.config/rclone/rclone.conf
cp -r ~/backup/gh/ ~/.config/gh/
cp ~/backup/local-bin/bt-spotify-switch ~/.local/bin/
chmod +x ~/.local/bin/bt-spotify-switch

# Dirs de Syncthing (antes de arrancar syncthing)
mkdir -p ~/media/audio ~/media/images ~/media/video
mkdir -p ~/dev ~/docs ~/edu ~/downloads
```

### User services runit
```bash
mkdir -p ~/.local/share/runit/sv
# install.sh ya habrá symlinkado syncthing y rclone-bisync desde runit/sv/
chmod +x ~/.local/share/runit/sv/syncthing/run
chmod +x ~/.local/share/runit/sv/rclone-bisync/run
```

### ~/.bash_profile (autostart Hyprland en TTY1)
```bash
if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" = "1" ]; then
    exec uwsm start hyprland.desktop
fi
```

### ~/.bashrc — variables de entorno a restaurar
```bash
export ANDROID_HOME=/opt/android-sdk
export DOCKER_BUILDKIT=1
source ~/.env  # contiene GROQ_API_KEY y otras secrets
# PATH:
export PATH="$PATH:$HOME/.cargo/bin:$HOME/.npm-global/bin:$HOME/.bun/bin"
export PATH="$PATH:$HOME/go/bin:$HOME/.dotfiles/scripts:$HOME/.local/bin"
export PATH="$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools"
source ~/.ghcup/env
eval "$(direnv hook bash)"
```

---

## Checklist de Verificación

- [ ] Hyprland arranca desde TTY1 via uwsm
- [ ] 3 monitores detectados (displaylink activo + setup_monitors_by_serial.sh)
- [ ] Audio funciona (pipewire via exec-once)
- [ ] `audio_watcher.sh` reinicia audio en dock/undock
- [ ] Super+V → shutdown/reboot funciona
- [ ] Syncthing sincroniza las 7 carpetas (audio, dev, docs, downloads, edu, images, video)
- [ ] rclone bisync ejecuta cada 5 min (relamidos-drive)
- [ ] bt-spotify-switch enruta audio al conectar Bluetooth
- [ ] Docker y libvirt operativos
- [ ] Dev tools: go, rustup, ghcup, bun, uv, java, android-sdk
- [ ] waybar, swaync, wofi funcionan
- [ ] Brightness y volume keys funcionan
- [ ] Screenshots con Print
