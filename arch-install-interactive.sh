```bash
#!/bin/bash
#=========================================================
#  Arch Linux Post-Install Helper Script (Interactive)
#  Makes setting up a fresh Arch install faster & clearer
#=========================================================

set -e  # exit on error

#---------------------------------------------------------
#  Default Settings (can be changed here or via prompts)
#---------------------------------------------------------
DEF_TIMEZONE="Europe/Budapest"
DEF_LOCALE="en_US.UTF-8"
DEF_KEYMAP="us"
DEF_HOSTNAME="arch"
DEF_USERNAME="vencel"
DEF_COMMENT="Vencel Molnár"
DEF_PASSWORD="temp1234"
EFI_DIR="/boot/efi"

#---------------------------------------------------------
#  Interactive Prompts
#---------------------------------------------------------
read -p "Timezone [${DEF_TIMEZONE}]: " TIMEZONE
TIMEZONE=${TIMEZONE:-$DEF_TIMEZONE}

read -p "Locale [${DEF_LOCALE}]: " LOCALE
LOCALE=${LOCALE:-$DEF_LOCALE}

read -p "Keymap [${DEF_KEYMAP}]: " KEYMAP
KEYMAP=${KEYMAP:-$DEF_KEYMAP}

read -p "Hostname [${DEF_HOSTNAME}]: " HOSTNAME
HOSTNAME=${HOSTNAME:-$DEF_HOSTNAME}

read -p "Username [${DEF_USERNAME}]: " USERNAME
USERNAME=${USERNAME:-$DEF_USERNAME}

read -p "Full Name/Comment [${DEF_COMMENT}]: " COMMENT
COMMENT=${COMMENT:-$DEF_COMMENT}

read -p "Temporary password for user [${DEF_PASSWORD}]: " PASSWORD
PASSWORD=${PASSWORD:-$DEF_PASSWORD}

echo
echo "Select GPU driver to install:"
echo "  1) AMD"
echo "  2) NVIDIA"
echo "  3) Intel (default, no driver needed)"
read -p "Choice [3]: " GPU_CHOICE
GPU_CHOICE=${GPU_CHOICE:-3}

#---------------------------------------------------------
#  Localization
#---------------------------------------------------------
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc

sed -i "s/#$LOCALE UTF-8/$LOCALE UTF-8/" /etc/locale.gen
locale-gen

echo "LANG=$LOCALE" > /etc/locale.conf
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

echo "$HOSTNAME" > /etc/hostname
cat << EOF > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain $HOSTNAME
EOF

#---------------------------------------------------------
#  Pacman Mirrorlist (Hungarian servers by default)
#---------------------------------------------------------
cat << EOF > /etc/pacman.d/mirrorlist
Server = https://ftp.ek-cer.hu/pub/mirrors/ftp.archlinux.org/\$repo/os/\$arch
Server = https://nova.quantum-mirror.hu/mirrors/pub/archlinux/\$repo/os/\$arch
Server = https://quantum-mirror.hu/mirrors/pub/archlinux/\$repo/os/\$arch
Server = https://super.quantum-mirror.hu/mirrors/pub/archlinux/\$repo/os/\$arch
EOF

sed -i 's/#Color/Color/' /etc/pacman.conf
pacman -Syy --noconfirm

#---------------------------------------------------------
#  Base Packages
#---------------------------------------------------------
pacman -S --noconfirm --needed \
    grub efibootmgr lvm2 networkmanager network-manager-applet \
    dialog wpa_supplicant mtools dosfstools reflector base-devel \
    linux-headers xdg-user-dirs xdg-utils gvfs gvfs-smb nfs-utils \
    inetutils net-tools dnsutils cups alsa-utils bash-completion \
    openssh rsync acpi acpi_call bridge-utils dnsmasq unbound \
    openbsd-netcat iptables-nft ipset firewalld sof-firmware \
    nss-mdns acpid os-prober ntfs-3g exfatprogs terminus-font \
    zip unzip unrar p7zip htop man-db man-pages pacman-contrib \
    vnstat ncdu iwd fdupes tree lsof

# GPU driver installation
case $GPU_CHOICE in
  1) pacman -S --noconfirm xf86-video-amdgpu ;;
  2) pacman -S --noconfirm nvidia nvidia-utils nvidia-settings ;;
  *) echo "Intel selected (no driver installation needed)" ;;
esac

#---------------------------------------------------------
#  Bootloader
#---------------------------------------------------------
grub-install --target=x86_64-efi --efi-directory="$EFI_DIR" --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

#---------------------------------------------------------
#  Enable System Services
#---------------------------------------------------------
systemctl enable NetworkManager
systemctl enable cups.service
systemctl enable paccache.timer
systemctl enable fstrim.timer
systemctl enable firewalld
systemctl enable acpid

#---------------------------------------------------------
#  User Setup
#---------------------------------------------------------
useradd -m -G wheel,users -c "$COMMENT" "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd

echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$USERNAME"

#---------------------------------------------------------
#  Finished
#---------------------------------------------------------
printf "\e[1;32mInstallation completed for user '$USERNAME' on host '$HOSTNAME'.\e[0m\n"
```
