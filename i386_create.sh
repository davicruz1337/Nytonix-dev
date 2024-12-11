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
sudo pacman -Syu --noconfirm base-devel grub efibootmgr squashfs-tools wget vim git gcc clang lightdm sway flatpak apparmor firejail networkmanager zsh neofetch dmenu papirus-icon-theme bc perl python cpio flex bison elfutils dosfstools

# Select the target device
TARGET_DEVICE="/dev/sda"
echo "Using target device: $TARGET_DEVICE"

# Unmount any mounted partitions
sudo umount "${TARGET_DEVICE}"* || true

# Partition the target device
echo "Partitioning $TARGET_DEVICE..."
sudo parted -s "$TARGET_DEVICE" mklabel msdos
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
sudo grub-install --target=i386-pc --boot-directory="$BUILD_DIR/boot" --recheck "$TARGET_DEVICE"

sudo grub-mkconfig -o "$BUILD_DIR/boot/grub/grub.cfg"

# Create minimal root filesystem
echo "Setting up root filesystem..."
mkdir -p "$BUILD_DIR"/{bin,sbin,etc,proc,sys,usr/bin,usr/sbin,home/nytonix,boot}
cp -a /bin/{bash,ls,mkdir,cat} "$BUILD_DIR/bin/"
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

# Unmount the partition
echo "Finalizing setup..."
sudo umount "$BUILD_DIR"

echo "Bootable system created on $TARGET_DEVICE. You can now boot it from the BIOS!"
