#!/bin/bash

ln -sf /usr/share/zoneinfo/Europe/Budapest /etc/localtime
hwclock --systohc
sed -i '177s/.//' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf
echo "KEYMAP=hu" >> /etc/vconsole.conf
echo "arch" >> /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 arch.localdomain arch" >> /etc/hosts
# echo root:temp1234 | chpasswd # if you want to have a password for root user

pacman -S grub efibootmgr lvm2 networkmanager network-manager-applet dialog wpa_supplicant mtools dosfstools reflector base-devel linux-headers avahi xdg-user-dirs xdg-utils gvfs gvfs-smb nfs-utils inetutils dnsutils bluez bluez-utils cups hplip alsa-utils bash-completion openssh rsync reflector acpi acpi_call virt-manager qemu qemu-arch-extra edk2-ovmf bridge-utils dnsmasq vde2 openbsd-netcat iptables-nft ipset firewalld flatpak sof-firmware nss-mdns acpid os-prober ntfs-3g exfatprogs terminus-font zip unzip unrar p7zip htop man-db man-pages pacman-contrib fwupd pipewire pipewire-alsa pipewire-pulse pipewire-jack tlp vnstat

# If you want to install KDE Plasma desktop environment
# pacman -S xorg xorg-server sddm plasma kwalletmanager konsole filelight ark gwenview kate okular spectacle dolphin kcalc simplescreenrecorder discover packagekit-qt5
# systemctl enable sddm

# pacman -S --noconfirm xf86-video-amdgpu
# pacman -S --noconfirm nvidia nvidia-utils nvidia-settings
# No package needed for intel cards

# If you want to install on virtualbox
# pacman -S virtualbox-guest-utils
# systemctl enable vboxservice.service

# If you want to install on lvm
# sed -i "s/autodetect modconf block/& lvm2/" /etc/mkinitcpio.conf
# mkinitcpio -p linux

sed -i '33s/.//' /etc/pacman.conf
sed -i '93s/.//' /etc/pacman.conf
sed -i '94s/.//' /etc/pacman.conf
sed -i '22 i --country Hungary' /etc/xdg/reflector/reflector.conf
pacman -Syy

# If esp is mounted under /efi
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# systemctl enable tlp
systemctl enable paccache.timer
systemctl enable vnstat.service
systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable cups.service
systemctl enable sshd
systemctl enable avahi-daemon
systemctl enable paccache.timer
systemctl enable reflector.timer
systemctl enable fstrim.timer
systemctl enable libvirtd
systemctl enable firewalld
systemctl enable acpid

useradd -mG wheel,users,libvirt vencel
echo vencel:temp1234 | chpasswd

echo "vencel ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/vencel

printf "\e[1;32mDone!\e[0m"
