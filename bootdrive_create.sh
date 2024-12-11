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
sudo pacman -Syu --noconfirm base-devel grub efibootmgr squashfs-tools wget vim git gcc clang lightdm sway flatpak apparmor firejail networkmanager zsh neofetch dmenu papirus-icon-theme bc perl python cpio flex bison elfutils openssl

# Select the target device
TARGET_DEVICE="/dev/sda"
echo "Using target device: $TARGET_DEVICE"

# Unmount any mounted partitions
sudo umount "${TARGET_DEVICE}"* || true

# Partition the target device
echo "Partitioning $TARGET_DEVICE..."
sudo parted -s "$TARGET_DEVICE" mklabel gpt
sudo parted -s "$TARGET_DEVICE" mkpart primary fat32 1MiB 512MiB
sudo parted -s "$TARGET_DEVICE" mkpart primary ext4 512MiB 100%
sudo parted -s "$TARGET_DEVICE" set 1 esp on

# Format the partitions
echo "Formatting partitions..."
sudo mkfs.vfat -F 32 "${TARGET_DEVICE}1"
sudo mkfs.ext4 "${TARGET_DEVICE}2"

# Mount partitions
echo "Mounting partitions..."
sudo mount "${TARGET_DEVICE}2" "$BUILD_DIR"
sudo mkdir -p "$BUILD_DIR/boot/efi"
sudo mount "${TARGET_DEVICE}1" "$BUILD_DIR/boot/efi"

# Create minimal root filesystem
echo "Setting up root filesystem..."
mkdir -p "$BUILD_DIR/{bin,sbin,etc,proc,sys,usr/bin,usr/sbin,home/nytonix,boot}"
cp -a /bin/{bash,ls,mkdir,cat} "$BUILD_DIR/bin/"
cp -a /usr/bin/{foot,dmenu} "$BUILD_DIR/usr/bin/"

# Configure GRUB
echo "Configuring GRUB..."
sudo grub-install --target=x86_64-efi --efi-directory="$BUILD_DIR/boot/efi" --boot-directory="$BUILD_DIR/boot" --removable --recheck

sudo grub-mkconfig -o "$BUILD_DIR/boot/grub/grub.cfg"

# Configure the system
echo "Configuring system..."
mkdir -p "$BUILD_DIR/etc"
echo "nytonixOS" > "$BUILD_DIR/etc/hostname"

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

# Clean up
echo "Unmounting partitions..."
sudo umount "$BUILD_DIR/boot/efi"
sudo umount "$BUILD_DIR"

echo "Bootable system created on $TARGET_DEVICE. You can now boot it from the BIOS!"
