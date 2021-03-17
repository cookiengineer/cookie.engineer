===
- date: 2021-03-03
- name: Android Privacy Guide
- tags: privacy, security
- type: software
- crux: Best Practices for an Android 10 smartphone that respects your Privacy and does not send anything to anyone that you don't want it to.
===

I was asked how I select my vendor, phone, and what kind of Mobile
Operating System I use. The amount of abandoned Android ROMs gets
probably larger every second, so choosing an Android ROM that will
be actively maintained next year is an important part of it.

The idea will also be to get as close to a Blob-Free Android as
possible, which means that the amount of available Smartphones
to choose from is very limited.

## Hardware

The amount of available Vendors is pretty limited. Most Android
devices are literally abandoned Kernel-wise right after they
were released. Custom Android OEM ROMs are typically end-of-life
with their software after half a year when the warranty ends.

## Smartphone Selection

So, we try to choose an Android device that's compatible with
an alternative AOSP (Android Open Source Project) ROM and that
doesn't send everything to Google.

I personally would recommend the Pine64 Pinephone, as it will
allow you a greater choice of Linux-based system images, but
the software stack isn't there yet to use it in practice.

Rather than that it's heavily recommended to use a Smartphone
where there are alternative Open Source OSes available and
where they list no upstream Linux kernel bugs. Upstream Linux
compatibility kind of implies that it's possible to run the
Smartphone without a Custom (outdated) OEM Kernel.

A good overview of that can be found in the wiki of postmarketOS
and its [Devices](https://wiki.postmarketos.org/wiki/Devices)
article. The workflow behind the project aims to integrate
patches with the upstream mainline Linux kernel, so the recommended
devices there have a very high chance of using a blob free Kernel.

## Operating System Selection

The most stable ROM with a huge community is probably LineageOS.
The [download page](https://download.lineageos.org) contains a
list of supported vendors, you should make sure to choose a
Smartphone that's up-to-date with `HEAD` and that contains a
newer Kernel (meaning version 5.10 or laterbuild as well.

Sometimes it's possible to use an old Kernel with Android 10+
or newer Android versions, but that will get you in a state
where you cannot update anymore.

In my case (due to curiousity) I decided to go for the
Pinephone and a Xiaomi Redmi Note device, as both Kernels
were available as source code repositories online and would
theoretically allow me to patch the kernel in case of a new
RCE that would appear in the future.

Given the history of Vendor-forked Linux kernels, it's safe
to assume that the likeliness of being remotely exploited
increases by using a Vendor-provided OEM Kernel. So you should
always choose a device that's compatible with the upstream
Linux Kernel and doesn't use an outdated one that's provided
by the manufacturer.

## Device Unlocking

Some vendors require a custom Unlocking Application that you
have to install on a `Windows VM` so that you can unlock your
device for Flashing the ROM on it.

Sometimes, this also comes with up to `60 days` of waiting
time until you are allowed to flash the device. Quite literally,
as this is the case for `Xiaomi's` Unlocking Application.

I always recommend to unlock your device as soon as you get
it, because at a later point in time, those websites always
disappear and are not available anymore; therefore you cannot
unlock your device.

It's typical for manufacturers to keep a track record of all
unlocked devices, so they know it's your `IMEI` that's running
an unlocked (flashed) Android ROM. They'll always claim it's
for warranty purposes, but they won't delete the data after
2 years either.

From a Privacy perspective this is a clear violation of the GDPR,
and there's not even a way to ensure deletion of that tracking
data. I tried contacting the legal representatives of some
companies in the past, but seemingly nobody gives a damn about
it.

## Android ROM

As an Android ROM, it's best to select a ROM that's close to
AOSP and doesn't infiltrate your devices with Google's Apps
(or the microG framework).

Therefore I would recommend to stick with something like
LineageOS, because over the years most of the other ROMs
appeared, went away, and came back again with various
maintainers that have no trust record of what they actually
did to build the ROM releases.

I also would not recommend to use a ROM that's distributed
by random people on the XDA developer forum, as it is known
that there were cases in the past where ROMs included malware
and it was discovered only years later.

Always use the upstream ROMs directly and do your modifications
afterwards, to be sure that's really what you did and what the
ROM includes.

## TWRP Installation

First, download the TWRP image for your device from 

TODO: TWRP Link

After the device was successfully unlocked via `fastboot oem unlock`,
it's time to flash TWRP on the recovery partition of your device.

Afterwards it's possible to enter TWRP by pressing the combination
of buttons on your device. Usually it's pressing `Power + Volume Down`
or `Power + Volume Up` for a couple seconds while booting, but it
varies from device to device.

```bash
fastboot flash recovery ./path/to/TWRP.img;
fastboot reboot bootloader;
```

## Android ROM Installation

## Software

### Rooting the Phone with Magisk

### Ad-Blocking with Blokada

### Spyware Scanning with App Warden

### Permission Management with Permission Manager X

### Suspending Apps with SuperFreeZ

### Tracker-Free Telegram FOSS

### Navigation with OSMAnd+

### Public Navigation with Oeffi

### Silent SMS with SMS Ping

### Terminal Emulation with Termux

### Wi-Fi Scanning with Wigle WiFi

