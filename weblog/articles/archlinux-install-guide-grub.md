===
- date: 2024-01-30
- name: Arch Linux Installation Guide (GRUB)
- tags: linux, devops, administration
- type: software, legacy
- crux: A compact installation guide with recommendations for an Arch Linux installation that uses full disk encryption with LUKS.
===


This compact installation guide is meant as an overview article to skim through and remind myself
of what's missing in an installation process. For any steps, the [Arch Wiki](https://wiki.archlinux.org)
is much more comprehensible and has a lot of information on how to deal with error cases.

Familiarity with the `cryptsetup` tool and `grub` is required for this guide.


## Boot Live ISO

### 1.1 USB flash drive

Download the image from the [Arch Linux download page](https://archlinux.org/download/),
flash it to the USB flash drive and then boot it on the target machine.

```bash
# replace /dev/sdX with the usb drive's identifier
sudo dd bs=4M conv=fsync oflag=direct status=progress if=/path/to/archlinux*.iso of=/dev/sdX;
```


### 1.2 Boot Live ISO

After bootup, set the timezones and the datetime correctly.
All timezones are available in the `/usr/share/zoneinfo` folder, in case you can't find yours.

```bash
# list available timezones
# timedatectl list-timezones;

timedatectl set-ntp true;
timedatectl set-timezone Europe/Berlin;
timedatectl status;
```


## Partition the Hard Drive

GRUB uses an old `MBR` (DOS-compatible) partition table.


### 2.1 Partition Table

```bash
fdisk /dev/sda;

# press o to create MBR (DOS) partition table
# press n to add new partition (use `+512M` as size when asked)

# press n to add new partition (use suggested size when asked)
# press t to change partition type to Linux and type `143` when asked
# press w to write to disk and exit
```

### 2.2 Format Boot Partition

```bash
mkfs.fat -F 32 /dev/sda1;
```

### 2.3 Format LUKS Encrypted Partition

```bash
cryptsetup luksFormat /dev/sda2;
# Enter your password when asked

cryptsetup open /dev/sda2 root;
mkfs.ext4 /dev/mapper/root;
```

### 2.4 Mount Partitions

```bash
# Already did this earlier
# cryptsetup open /dev/sda2 root;

mount /dev/mapper/root /mnt;

mkdir -p /mnt/boot;
mount /dev/sda1 /mnt/boot;
```

### 2.5 Bootstrap Arch Linux

```bash
pacstrap /mnt base base-devel linux linux-firmware vim sudo;
genfstab -U /mnt > /mnt/etc/fstab;

arch-chroot /mnt;
```


## Configure Arch Linux

**IMPORTANT**: Everything from here on out is executed inside the `arch-chroot` environment!


### 3.1 Configure Users

```bash
# Edit the /etc/sudoers file and uncomment the line `%wheel ALL=(ALL) ALL`.
vim /etc/sudoers;
```

### 3.2 Configure Locale

```bash
# Uncomment en_US.UTF-8
vim /etc/locale.gen;

echo "LANG=en_US.UTF-8" > /etc/locale.conf;
locale-gen;
```

### 3.3 Configure Timezone

```bash
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime;
hwclock --systohc;
```

### 3.4 Configure Hostname

```bash
echo "myhostname" > /etc/hostname;

echo "127.0.0.1 localhost" > /etc/hosts;
echo "::1 localhost" >> /etc/hosts;
echo "127.0.1.1 myhostname" >> /etc/hosts;
echo "ff02::1 ip6-allnodes" >> /etc/hosts;
echo "ff02::2 ip6-allrouters" >> /etc/hosts;
```

### 3.5 Configure Nameservers

Add DNS nameservers to the `/etc/resolv.conf` file:

```bash
echo "nameserver 1.0.0.1" > /etc/resolv.conf;
echo "nameserver 1.1.1.1" >> /etc/resolv.conf;
```

### 3.6 Configure Admin User

```bash
# optionally give root user a password
passwd root;

useradd -m myusername;
usermod -aG users,wheel myusername;
passwd myusername;
```


## Install Bootloader and Kernel Image

GRUB is pretty failsafe because it has a lot of support for legacy bootloaders,
such as old Windows kernels.

### 4.1 Encrypt Hook

Add the `encrypt` hook to the `HOOKS` the right place **before** the `filesystems`
hook into the `/etc/mkinitcpio.conf` file:

```config
HOOKS=(base udev autodetect modconf kms block encrypt filesystems keyboard fsck)
```

### 4.2 Configure GRUB Bootloader

Find out the `UUID` of the `LUKS` partition and replace the `UUID` variable later.
The UUID of the `sda2` partition is not the same as the one from the mounted `ext4`
partition, so be careful to not use the wrong one.

```bash
lsblk -f;

# example output
NAME     FSTYPE      FSVER LABEL UUID                                 FSAVAIL FSUSE% MOUNTPOINTS
sda
├─sda1   vfat        FAT32       CAB5-B580                             366.3M    28% /boot
└─sda2   crypto_LUKS 2           4e31973f-1e77-4061-aadf-d77a057832b2
  └─root ext4        1.0         ce9d9c8c-90d4-4aea-bbf3-c345e21c2f8a     12G    90% /
```

GRUB uses the `GRUB_CMDLINE_LINUX_DEFAULT` parameter which needs to be changed in
the `/etc/default/grub` file:

```config
# replace $UUID with correct one
GRUB_CMDLINE_LINUX_DEFAULT="resume=UUID=$UUID udev.log_priority=3 cryptdevice=UUID=$UUID:root root=/dev/mapper/root rw"
```

### 4.3 Regenerate Image and Install Bootloader

Regenerate the Linux Images and install the GRUB Bootloader:

```bash
mkinitcpio -P;
grub-install --target=i386-pc /dev/sda;
grub-mkconfig -o /boot/grub/grub.cfg;
```


## Configure Server Usage

### 5.1 Configure Network Interface

Arch Linux comes with SystemD, so it makes sense to reuse `systemd-networkd`.
When you're running a server, you're probably using a LAN/ethernet cable.

In case you don't know your network interface's name, you can see that with `ip addr`.

Usually they are similar to `enp0s25`, `enp0s3` or `eno1`, depending on your mainboard
and its provided EFI settings (the name is derived from UEFI variables).

Change it accordingly in the config files below:

```bash
systemctl enable systemd-networkd;
```

### 5.2a DHCP Configuration

Edit the `/etc/systemd/network/20-wired.network` file:

```systemd
[Match]
Name=enp0s25

[Network]
DHCP=yes
```

### 5.2b Static Configuration

Edit the `/etc/systemd/network/20-wired.network` file:

```systemd
[Match]
Name=enp0s25

[Network]
Address=192.168.0.123/24
Gateway=192.168.0.1
DNS=192.168.0.1
```

### 5.3 Configure OpenSSH

Servers usually don't have a keyboard installed, so it makes sense to install OpenSSH now:

```bash
pacman -S openssh;
systemctl enable sshd.service;
```


## Update and Reboot

### 6.1 Update Keyring

Sometimes the ISO can be outdated and keyrings will break later, and that's kind
of annoying to debug. Make sure to update them before you reboot:

```bash
pacman -Sy archlinux-keyring;
```

### 6.2 Reboot

Exit the `arch-chroot` environment and go back to the USB live system shell, then
restart the machine:

```bash
exit;
reboot;
```

