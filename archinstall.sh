#!/bin/bash
# Minimalistic, uniform, semi-interactive Arch installer helper (systemd-boot)
set -euo pipefail

#===============================================================================
# Helper functions
#===============================================================================
ask() {
    read -rp "$1 [y/N]: " ans
    [[ "$ans" =~ ^[Yy]$ ]]
}

input_default() {
    local prompt="$1"
    local default="$2"
    read -rp "$prompt [$default]: " val
    printf "%s" "${val:-$default}"
}

write_file() {
    local path="$1"; shift
    install -Dm644 /dev/stdin "$path" <<< "$*"
}

enable_services() {
    for svc in "$@"; do
        systemctl enable "$svc"
    done
}

#===============================================================================
# Package & Service definitions (modular)
#===============================================================================
BASE_PKGS=(
    systemd-boot-pacman-hook networkmanager dialog wpa_supplicant mtools dosfstools
    reflector base-devel linux-headers linux-lts linux-lts-headers xdg-user-dirs
    xdg-utils gvfs gvfs-smb nfs-utils inetutils net-tools dnsutils cups alsa-utils
    bash-completion openssh rsync acpi acpi_call bridge-utils dnsmasq unbound
    openbsd-netcat iptables-nft ipset firewalld sof-firmware nss-mdns acpid
    ntfs-3g exfatprogs terminus-font zip unzip unrar p7zip htop man-db man-pages
    pacman-contrib vnstat ncdu iwd fdupes tree lsof wget
)

LVM_PKGS=(lvm2)

HYPERV_PKGS=(hyperv)
HYPERV_SERVICES=(
    hv_fcopy_daemon.service
    hv_kvp_daemon.service
    hv_vss_daemon.service
)

BLUETOOTH_PKGS=(bluez bluez-utils)
BLUETOOTH_SERVICES=(bluetooth.service)

LIBVIRT_PKGS=(libvirt)
LIBVIRT_SERVICES=(libvirtd.service)

GPU_PKG_AMD=(xf86-video-amdgpu)
GPU_PKG_NVIDIA=(nvidia nvidia-utils nvidia-settings)
GPU_PKG_INTEL=()   # No special packages

BASE_SERVICES=(
    NetworkManager
    cups.service
    paccache.timer
    fstrim.timer
    firewalld
    acpid
    vnstat
)

# Master arrays to be built dynamically
PACKAGES=()
SERVICES=()

#===============================================================================
# Base system configuration
#===============================================================================
ZONE="$(input_default "Timezone" "Europe/Budapest")"
ln -sf "/usr/share/zoneinfo/$ZONE" /etc/localtime
hwclock --systohc

sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen

write_file /etc/locale.conf "LANG=en_US.UTF-8"
write_file /etc/vconsole.conf "KEYMAP=$(input_default "Console keymap" "us")"

HOSTNAME="$(input_default "Hostname" "arch")"
write_file /etc/hostname "$HOSTNAME"

write_file /etc/hosts \
"127.0.0.1 localhost
::1       localhost
127.0.1.1 ${HOSTNAME}.localdomain ${HOSTNAME}
"

if ask "Set temporary root password?"; then
    passwd root
fi

#===============================================================================
# Mirrorlist
#===============================================================================
if ask "Use Hungarian Arch mirrors?"; then
write_file /etc/pacman.d/mirrorlist "
Server = https://ftp.ek-cer.hu/pub/mirrors/ftp.archlinux.org/\$repo/os/\$arch
Server = https://nova.quantum-mirror.hu/mirrors/pub/archlinux/\$repo/os/\$arch
Server = https://quantum-mirror.hu/mirrors/pub/archlinux/\$repo/os/\$arch
Server = https://super.quantum-mirror.hu/mirrors/pub/archlinux/\$repo/os/\$arch
"
fi

sed -i 's/#Color/Color/' /etc/pacman.conf
pacman -Syy

#===============================================================================
# Package aggregation
#===============================================================================
if ask "Install base recommended packages?"; then
    PACKAGES+=("${BASE_PKGS[@]}")
fi

# LVM
if ask "Is the root partition LVM?"; then
    PACKAGES+=("${LVM_PKGS[@]}")
    sed -i 's/\(block\)/\1 lvm2/' /etc/mkinitcpio.conf
fi

# Hyper-V
if ask "Is this system running under Hyper-V?"; then
    PACKAGES+=("${HYPERV_PKGS[@]}")
    SERVICES+=("${HYPERV_SERVICES[@]}")
fi

# Bluetooth
if ask "Does this system have bluetooth?"; then
    PACKAGES+=("${BLUETOOTH_PKGS[@]}")
    SERVICES+=("${BLUETOOTH_SERVICES[@]}")
fi

# Libvirt
if ask "Will this system use libvirt virtualization?"; then
    PACKAGES+=("${LIBVIRT_PKGS[@]}")
    SERVICES+=("${LIBVIRT_SERVICES[@]}")
fi

# GPU
echo "Choose GPU driver (empty = none):"
printf "1) AMD\n2) NVIDIA\n3) Intel or VM\n"

while true; do
    read -rp "Choice: " gpu
    case "$gpu" in
        1) PACKAGES+=("${GPU_PKG_AMD[@]}"); break ;;
        2) PACKAGES+=("${GPU_PKG_NVIDIA[@]}"); break ;;
        3|"") break ;;
        *) echo "Invalid option." ;;
    esac
done

#===============================================================================
# Install all aggregated packages
#===============================================================================
if [[ ${#PACKAGES[@]} -gt 0 ]]; then
    pacman -S --needed "${PACKAGES[@]}"
fi

mkinitcpio -P

#===============================================================================
# systemd-boot setup
#===============================================================================
EFI_DIR="$(input_default "EFI mount dir" "/efi")"
bootctl --esp-path="$EFI_DIR" install

ROOT_UUID="$(blkid -s UUID -o value "$(findmnt -no SOURCE /)")"

mkdir -p "$EFI_DIR/loader/entries"

write_file "$EFI_DIR/loader/loader.conf" \
"default arch.conf
timeout 3
console-mode auto
editor no
"

write_file "$EFI_DIR/loader/entries/arch.conf" \
"title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options root=UUID=$ROOT_UUID rw
"

write_file "$EFI_DIR/loader/entries/arch-fallback.conf" \
"title Arch Linux (fallback)
linux /vmlinuz-linux
initrd /initramfs-linux-fallback.img
options root=UUID=$ROOT_UUID rw
"

write_file "$EFI_DIR/loader/entries/arch-lts.conf" \
"title Arch Linux (LTS)
linux /vmlinuz-linux-lts
initrd /initramfs-linux-lts.img
options root=UUID=$ROOT_UUID rw
"

#===============================================================================
# Add base services and enable all
#===============================================================================
SERVICES+=("${BASE_SERVICES[@]}")
enable_services "${SERVICES[@]}"

#===============================================================================
# Create user
#===============================================================================
if ask "Create a user?"; then
    USERNAME="$(input_default "Username" "vencel")"
    FULLNAME="$(input_default "Full name" "Vencel Molnár")"

    useradd -m -G wheel,users -c "$FULLNAME" "$USERNAME"
    passwd "$USERNAME"

    if ask "Allow passwordless sudo for $USERNAME?"; then
        write_file "/etc/sudoers.d/$USERNAME" "$USERNAME ALL=(ALL) NOPASSWD:ALL"
    fi
fi

echo -e "\e[1;32mInstallation script completed.\e[0m"
