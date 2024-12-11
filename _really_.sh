#!/bin/bash

# Fail on errors
set -e

# Define paths
BUILD_DIR="/nytonix-tmp"
KERNEL_VERSION="5.15.132"
DISTRO_NAME="nytonixOS"

# Logo ASCII for NytonixOS
LOGO_ASCII="""
[...     [..
[. [..   [..
[.. [..  [..
[..  [.. [..
[..   [. [..
[..    [. ..
[..      [..
"""

echo "Setting up environment..."
mkdir -p "$BUILD_DIR"

# Install dependencies
echo "Installing base dependencies..."
sudo pacman -Syu --noconfirm base-devel grub efibootmgr squashfs-tools wget vim git gcc clang lightdm sway flatpak apparmor firejail networkmanager zsh neofetch dmenu papirus-icon-theme bc perl python cpio flex bison elfutils dosfstools util-linux

# Select the target device
TARGET_DEVICE="/dev/sda"
echo "Using target device: $TARGET_DEVICE"

# Unmount any mounted partitions
sudo umount "${TARGET_DEVICE}"* || true

# Partition the target device
echo "Partitioning $TARGET_DEVICE..."
sudo parted -s "$TARGET_DEVICE" mklabel gpt
sudo parted -s "$TARGET_DEVICE" mkpart primary fat32 1MiB 100%
sudo parted -s "$TARGET_DEVICE" set 1 boot on

# Format the partition
echo "Formatting partition..."
sudo mkfs.vfat -F 32 "${TARGET_DEVICE}1"

# Mount partition
echo "Mounting partition..."
sudo mount "${TARGET_DEVICE}1" "$BUILD_DIR"

# Configure GRUB
echo "Configuring GRUB..."
sudo grub-install --target=x86_64-efi --efi-directory="$BUILD_DIR" --boot-directory="$BUILD_DIR/boot" --removable --recheck

sudo grub-mkconfig -o "$BUILD_DIR/boot/grub/grub.cfg"

# Create minimal root filesystem
echo "Setting up root filesystem..."
mkdir -p "$BUILD_DIR"/{bin,sbin,etc,proc,sys,usr/bin,usr/sbin,home/nytonix,boot}
cp -a /bin/{bash,ls,mkdir,cat,mount,umount} "$BUILD_DIR/bin/"
cp -a /usr/bin/{foot,dmenu} "$BUILD_DIR/usr/bin/"

# Configure Sway
echo "Configuring Sway..."
mkdir -p "$BUILD_DIR/etc/sway"
cat > "$BUILD_DIR/etc/sway/config" <<EOF
# Sway Configuration for NytonixOS
set \$mod Mod4

# Default terminal
bindsym \$mod+Return exec foot

# Application launcher
bindsym \$mod+d exec dmenu_run

# Focus
bindsym \$mod+h focus left
bindsym \$mod+l focus right
bindsym \$mod+j focus down
bindsym \$mod+k focus up

# Layouts
bindsym \$mod+e splith
bindsym \$mod+s splitv
bindsym \$mod+f fullscreen
bindsym \$mod+q kill

# Background
output * bg #0000FF fill
EOF

# Configure Neofetch
echo "Configuring Neofetch..."
mkdir -p "$BUILD_DIR/usr/share/neofetch/ascii"
mkdir -p "$BUILD_DIR/etc/neofetch"
cat > "$BUILD_DIR/etc/neofetch/config.conf" <<EOF
info "Custom Linux Distribution"
distro_logo="custom"
EOF

cat > "$BUILD_DIR/usr/share/neofetch/ascii/nytonix" <<EOF
$LOGO_ASCII
EOF

# Install the installer script as a bin
echo "Creating installer script..."
mkdir -p "$BUILD_DIR/usr/local/bin"
cat > "$BUILD_DIR/usr/local/bin/install.sh" <<'EOF'
#!/bin/bash

set -e

# Display Nytonix logo animation
frames=(
".______  "
":      \ "
"|       |"
"|   |   |"
"|___|   |"
"    |___|"
"         "
"         "
)

for frame in "${frames[@]}"; do
    clear
    echo -e "\n\n\n\n\n\n$frame"
    sleep 0.2
done

# Display disks for user
echo "Available disks:"
lsblk -d -o NAME,SIZE | sort -k2 -h

echo -n "Enter the disk to install NytonixOS (e.g., /dev/sda): "
read DISK

# Partition and format the disk
sudo parted -s "$DISK" mklabel gpt
sudo parted -s "$DISK" mkpart primary fat32 1MiB 512MiB
sudo parted -s "$DISK" mkpart primary fat32 512MiB 100%
sudo parted -s "$DISK" set 1 esp on

sudo mkfs.vfat -F 32 "${DISK}1"
sudo mkfs.vfat -F 32 "${DISK}2"

# Mount the partitions
sudo mount "${DISK}2" /mnt
sudo mkdir -p /mnt/boot/efi
sudo mount "${DISK}1" /mnt/boot/efi

# Install base system
sudo pacstrap /mnt base base-devel linux linux-firmware grub efibootmgr sway networkmanager apt

# Install open-source drivers
sudo pacstrap /mnt mesa xf86-video-vesa xf86-video-amdgpu xf86-video-nouveau xf86-video-intel

# Configure the system
echo "Configuring the system..."
echo "nytonixOS" | sudo tee /mnt/etc/hostname
sudo arch-chroot /mnt systemctl enable NetworkManager
sudo arch-chroot /mnt systemctl enable sway
sudo arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --boot-directory=/boot --recheck
sudo arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# Set up user
echo -n "Set root password: "
read -s ROOT_PASSWORD
sudo arch-chroot /mnt /bin/bash -c "echo root:$ROOT_PASSWORD | chpasswd"

echo -n "Enter a username: "
read USERNAME
sudo arch-chroot /mnt useradd -m \$USERNAME

echo -n "Set password for \$USERNAME: "
read -s USER_PASSWORD
sudo arch-chroot /mnt /bin/bash -c "echo \$USERNAME:$USER_PASSWORD | chpasswd"

# Install basic utilities and terminal emulator
sudo arch-chroot /mnt pacman -S --noconfirm foot htop vim neofetch

# Finish
echo "Installation complete! Reboot to enjoy NytonixOS."
EOF
chmod +x "$BUILD_DIR/usr/local/bin/install.sh"


# Unmount the partition
echo "Finalizing setup..."
sudo umount "$BUILD_DIR"

echo "Bootable system created on $TARGET_DEVICE. You can now boot it from the BIOS! The installer script is available as 'install.sh'."
