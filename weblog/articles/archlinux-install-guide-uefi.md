===
- date: 2024-01-31
- name: Arch Linux Installation Guide (UEFI)
- tags: linux, devops, administration
- type: software, legacy
- crux: A compact installation guide with recommendations for an Arch Linux installation that uses full disk encryption with LUKS.
===


This compact installation guide is meant as an overview article to skim through and remind myself
of what's missing in an installation process. For any step, the [Arch Wiki](https://wiki.archlinux.org)
is much more comprehensible and has a lot of information on how to deal with error cases.

Familarity with the `cryptsetup` tool and `systemd-boot` is required for this guide.


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

There's two ways to parition the hard drive.

The new UEFI way uses a GPT partition table, where you also have to have at least two
partitions. Due to bugs and quirks of old BIOS versions, 512MB EFI partition size (which
hosts both your kernel images and the EFI bootloader) is recommended, the second partition
can be your `/` root partition.

I'll spare the whole bullshit about swapping partitions, the dangers of them and what kind
of RAM your system has to have. You decide whether you wanna have swap space on your hard
drive on your own. In my case all my systems have far beyond 16GB of RAM, so swapping pretty
much never occurs and my operating modes never are rare on system memory.

### 2.1 Partition Table

```bash
fdisk /dev/sda;

# press g to create GPT partition table
# press n to add new partition, use `+512M` as size when asked
# press t to change partition type to ESP/EFI and type `uefi` when asked

# press n to add new partition (use suggested size when asked)
# press t to change partition type to Linux and type `143` when asked
# press w to write to disk and exit
```

### 2.2 Create ESP/EFI Boot Partition

```bash
mkfs.fat -F 32 /dev/sda1;
```

### 2.3 Format LUKS Encrypted partition

```bash
cryptsetup luksFormat /dev/sda2;
# Enter your password when asked

cryptsetup open /dev/nvme0n1p2 root;
mkfs.ext4 /dev/mapper/root;
```

### 2.4 Mount Partitions

```bash
# Already did this earlier:
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
# Edit the /etc/sudoers file and uncomment the line "%wheel ALL=(ALL) ALL".
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

Add DNS nameservers in the `/etc/resolv.conf` file:

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

`systemd-boot` requires EFI and therefore can only be used if you chose the GPT/EFI
Boot Partition option earlier.

### 4.1 Encrypt Hook

Add the `encrypt` hook to the `HOOKS` the right place **before** the `filesystems`
hook into the `/etc/mkinitcpio.conf` file:

```config
#                                           |>  here  <|
HOOKS=(base udev autodetect modconf kms block encrypt filesystems keyboard fsck)
```

Regenerate the Linux Images and install the SystemD-Bootloader:

```bash
mkinitcpio -P;
bootctl --esp-path=/boot --boot-path=/boot install;
```

### 4.2 Configure SystemD Bootloader

```bash
echo "default arch.conf" > /boot/loader/loader.conf;
echo "timeout 3" >> /boot/loader/loader.conf;
echo "editor no" >> /boot/loader/loader.conf;
```

Remember the UUID of the `LUKS` partition (not the mounted `ext4` partition!) and
replace the `$UUID` variable later. In the following example, the UUID of `sda2`
is necessary and you can see the different UUID for the nested/mapped/mounted
partition inside the encrypted partition:

```bash
lsblk -f;

# example output
NAME     FSTYPE      FSVER LABEL UUID                                 FSAVAIL FSUSE% MOUNTPOINTS
sda
├─sda1   vfat        FAT32       CAB5-B580                             366.3M    28% /boot
└─sda2   crypto_LUKS 2           4e31973f-1e77-4061-aadf-d77a057832b2
  └─root ext4        1.0         ce9d9c8c-90d4-4aea-bbf3-c345e21c2f8a     12G    90% /
```

Configure the Bootloader Entry for `Arch Linux`:

```bash
# You need to change this (see above):
export UUID="4e31973f-1e77-4061-aadf-d77a057832b2";

echo "title Arch Linux" > /boot/loader/entries/arch.conf;
echo "linux /vmlinuz-linux" >> /boot/loader/entries/arch.conf;
echo "initrd /initramfs-linux" >> /boot/loader/entries/arch.conf;
echo "options cryptdevice=UUID=$UUID:root root=/dev/mapper/root rw" >> /boot/loader/entries/arch.conf;
```


## Configure for Server Usage

### 5.1 Configure Network Interfaces

Arch Linux comes with SystemD, so it makes sense to reuse `systemd-networkd`.
When you're running a server, you're probably using a LAN/ethernet cable.

In case you don't know your network interface's name, you can see that with `ip addr`.

Usually they are similar to `enp0s25`, `enp0s3` or `eno1`, depending on your mainboard
and its provided EFI settings (the name is derived from UEFI variables). Change it
accordingly in the config files below.

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

Servers usually don't have a keyboard or KVM switch installed, so it makes sense to install OpenSSH now:

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

Exit the `arch-chroot` and go back to the USB live system shell, then restart
the machine.

```bash
exit;

# restarts machine
reboot;
```

